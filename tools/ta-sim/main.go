/*
 * Copyright (C) 2020  Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package main

import (
	"bytes"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/tls"
	"crypto/x509"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"encoding/xml"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"

	client "github.com/intel-secl/intel-secl/v5/pkg/clients/ta"
	"github.com/intel-secl/intel-secl/v5/pkg/lib/common/crypt"
	tamodel "github.com/intel-secl/intel-secl/v5/pkg/model/ta"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/spf13/viper"
)

var Version = ""
var GitHash = ""
var BuildDate = ""

const (
	communicationModeHttp     = "http"
	communicationModeOutbound = "outbound"
)

type AppConfig struct {
	PortStart              int
	Servers                int
	DistinctFlavors        int
	QuoteDelayMs           int
	RequestVolume          int
	RequestVolumeDelayMs   int
	TrustedHostsPercentage int
	ApiUserName            string
	ApiUserPassword        string
	HvsApiUrl              string
	AasApiUrl              string
	CmsApiUrl              string
	SimulatorIP            string
	NatsServers            []string
	TaSimServiceMode       string
	TaHostId               string

	sslCertPath              string
	sslKeyPath               string
	tpmQuotePath             string
	hostInfoPath             string
	aikCertPath              string
	aikKeyPath               string
	bindingKeyPath           string
	hwUuidMapPath            string
	natsTaSimCredentialsPath string
	natsTaSubCredentialsPath string
}

type quoteSections struct {
	infoPreNonceSha1  []byte
	infoPostNonceSha1 []byte
	afterSignature    []byte
}
type controller struct {
	aikCert        *x509.Certificate
	aikKey         *rsa.PrivateKey
	bindingKeyCert []byte
	tpmQuote       *tamodel.TpmQuoteResponse
	quoteParts     quoteSections

	hostInfo  tamodel.HostInfo
	config    *AppConfig
	hwUuidMap []string
}

func getApplicationData() (*AppConfig, error) {

	ac := &AppConfig{}
	homePath := "/opt/go-ta-simulator/"

	if os.Getenv("GO_TA_SIM_HOME") != "" {
		homePath = os.Getenv("GO_TA_SIM_HOME")
	}
	viper.SetConfigName("config")
	viper.AddConfigPath(filepath.FromSlash(homePath + "configuration"))
	viper.SetConfigType("yml")

	if err := viper.ReadInConfig(); err != nil {
		return nil, fmt.Errorf("error reading config file, %s", err)
	}

	if err := viper.Unmarshal(ac); err != nil {
		return nil, fmt.Errorf("Unable to decode into struct, %v", err)
	}

	// sanitize some of the default values
	if ac.PortStart == 0 {
		ac.PortStart = 10000
	}
	if ac.Servers == 0 {
		ac.Servers = 1
	}
	if ac.DistinctFlavors == 0 {
		ac.DistinctFlavors = 1
	}
	if ac.QuoteDelayMs == 0 {
		ac.QuoteDelayMs = 1000
	}
	if ac.TrustedHostsPercentage < 1 || ac.TrustedHostsPercentage > 100 {
		ac.TrustedHostsPercentage = 100
	}

	if len(ac.NatsServers) == 0 && ac.TaHostId == "" {
		ac.TaSimServiceMode = communicationModeHttp
	} else {
		ac.TaSimServiceMode = communicationModeOutbound
	}

	ac.aikCertPath = filepath.FromSlash(homePath + "configuration/aik.cert.pem")
	ac.aikKeyPath = filepath.FromSlash(homePath + "configuration/aik.key.pem")
	ac.bindingKeyPath = filepath.FromSlash(homePath + "configuration/bk.cert")
	ac.hostInfoPath = filepath.FromSlash(homePath + "repository/host_info.json")
	ac.tpmQuotePath = filepath.FromSlash(homePath + "repository/quote.xml")
	ac.natsTaSimCredentialsPath = filepath.FromSlash(homePath + "repository/ta-sim.creds")
	ac.natsTaSubCredentialsPath = filepath.FromSlash(homePath + "repository/ta-sub.creds")
	ac.sslCertPath = filepath.FromSlash(homePath + "configuration/cert.pem")
	ac.sslKeyPath = filepath.FromSlash(homePath + "configuration/key.pem")
	ac.sslKeyPath = filepath.FromSlash(homePath + "configuration/key.pem")
	ac.hwUuidMapPath = filepath.FromSlash(homePath + "configuration/hw_uuid_map.json")

	return ac, nil
}

type hwUuidMap struct {
	Port   int    `json:"port"`
	HwUuid string `json:"hw_uuid"`
}

// This function takes in the contents of the file with the host uuid data
// When entries are found, they are reused. If there are no entries, then new
// ones are created. The file can then be saved back to disk
func loadHwUuidData(data []byte, portStart, servers int) ([]string, bool, []hwUuidMap) {

	// make a slice to represent the hwUuids so that we can reference them by index
	hwUuidSlice := make([]string, servers)
	mp := make([]hwUuidMap, 0)
	// we can ignore the error below since
	json.Unmarshal(data, &mp)
	for _, item := range mp {
		if item.Port-portStart >= 0 && item.Port-portStart < servers {
			hwUuidSlice[item.Port-portStart] = item.HwUuid
		}
	}
	var save bool
	for i := 0; i < servers; i++ {
		if hwUuidSlice[i] == "" {
			save = true
			hwUuidSlice[i] = uuid.New().String()
			mp = append(mp, hwUuidMap{
				Port:   i + portStart,
				HwUuid: hwUuidSlice[i],
			})
		}
	}
	return hwUuidSlice, save, mp
}

func loadNSaveHwUuidFile(hwUuidMapPath string, portStart, servers int) ([]string, error) {
	var err error
	var hwUuidData []byte
	if hwUuidData, err = ioutil.ReadFile(hwUuidMapPath); err != nil {
		log.Info("Could not find hw uuid file. Will create a new one")
	}

	hwUuidMap, save, mapToSave := loadHwUuidData(hwUuidData, portStart, servers)
	if save == true {
		// save the file to disk
		var data []byte
		if data, err = json.MarshalIndent(mapToSave, "", "\t"); err != nil {
			return nil, errors.Wrap(err, "could not marshal hw uuid data")
		}
		if err = ioutil.WriteFile(hwUuidMapPath, data, 0644); err != nil {
			return nil, errors.Wrap(err, "could not write hw uuid data to file")
		}
	}
	return hwUuidMap, nil

}

func NewController(ac *AppConfig) (*controller, error) {
	ctrlr := &controller{}
	var err error
	if quoteXml, err := ioutil.ReadFile(ac.tpmQuotePath); err != nil {
		return nil, errors.Wrap(err, "Could not read tpm quote file")
	} else {
		var quoteResponse tamodel.TpmQuoteResponse
		if err = xml.Unmarshal(quoteXml, &quoteResponse); err != nil {
			return nil, errors.Wrap(err, "Could not unmarshal xml tpm quote response file")
		}
		ctrlr.tpmQuote = &quoteResponse
		if origQuoteBytes, err := base64.StdEncoding.DecodeString(quoteResponse.Quote); err != nil {
			return nil, errors.Wrap(err, "could not convert quote to base64")
		} else {
			// seperate out the quote into 3 parts. The first one is part of the quote before the
			// sha256 of the nonce.
			// second part is the where the sha256 of the nonce is at. We do not need to save this part
			// We can just ignore it since we will be adding the sha256 of the new nonce
			// Third part is the rest of the quote.

			//determine the end of the quote. the first 2 bytes represent the length of the quote
			index := 0
			endOfQuoteIdx := int(binary.BigEndian.Uint16(origQuoteBytes[0:2])) + 2

			// advance the index by 8 bytes - 2 for the quote info length
			// and 6 more bytes that are not clear. Refer VerifyQuoteAndGetPCRManifest in
			// intel_host_connector library.
			index += 8

			tpm2bNameSize := binary.BigEndian.Uint16(origQuoteBytes[index : index+2])

			index += 2 + int(tpm2bNameSize)
			tpm2bDataSize := binary.BigEndian.Uint16(origQuoteBytes[index : index+2])
			ctrlr.quoteParts.infoPreNonceSha1 = origQuoteBytes[:index+2]

			index += 2
			//tpm2bData := origQuoteBytes[index : index+int(tpm2bDataSize)]
			index += int(tpm2bDataSize)
			// there are 6 bytes (3 x 2 byte integers) at the end of the quote that indicates
			// Signature Algorigthm (20), signature hash algorithm(11) and size of signature(256)
			ctrlr.quoteParts.infoPostNonceSha1 = origQuoteBytes[index : endOfQuoteIdx+6]

			// make sure that the last 2 bytes of this has a value of 256 bytes... otherwise, we have a
			// problem with the original quote. Error out
			if binary.BigEndian.Uint16(ctrlr.quoteParts.infoPostNonceSha1[len(ctrlr.quoteParts.infoPostNonceSha1)-2:]) != 256 {
				return nil, errors.New("original quote signature length is not 256. Incorrect quote")
			}
			ctrlr.quoteParts.afterSignature = origQuoteBytes[endOfQuoteIdx+6+256:]

		}
		ctrlr.tpmQuote.Quote = ""

	}
	if aikPemBytes, err := ioutil.ReadFile(ac.aikCertPath); err != nil {
		return nil, errors.Wrap(err, "Could not open aik certificate file")
	} else {
		if ctrlr.aikCert, err = crypt.GetCertFromPem(aikPemBytes); err != nil {
			return nil, errors.Wrap(err, "could not parse certificate from pem file")
		}
		ctrlr.tpmQuote.Aik = base64.StdEncoding.EncodeToString(aikPemBytes)
	}
	if ctrlr.bindingKeyCert, err = ioutil.ReadFile(ac.bindingKeyPath); err != nil {
		log.Error("Could not read binding key file - skipping")
	}
	if hd, err := ioutil.ReadFile(ac.hostInfoPath); err != nil {
		return nil, errors.Wrap(err, "Could not read host info file")
	} else {
		if err = json.Unmarshal(hd, &ctrlr.hostInfo); err != nil {
			return nil, errors.Wrap(err, "Could not decode json for host info")
		}
	}
	if pk, err := crypt.GetPrivateKeyFromPKCS8File(ac.aikKeyPath); err != nil {
		return nil, errors.Wrap(err, "Could not get private key to sign quote")
	} else {
		var ok bool
		if ctrlr.aikKey, ok = pk.(*rsa.PrivateKey); !ok {
			return nil, errors.Wrap(err, "key is not of an rsa key. Need an rsa key for this operation")
		}
	}

	if ctrlr.hwUuidMap, err = loadNSaveHwUuidFile(ac.hwUuidMapPath, ac.PortStart, ac.Servers); err != nil {
		return nil, errors.Wrap(err, "could not load the hw uuids")
	}

	ctrlr.config = ac
	return ctrlr, nil
}

func (ctrl controller) hello(w http.ResponseWriter, r *http.Request) {
	_, _ = fmt.Fprint(w, "Hello from Server on: ")
	_, _ = fmt.Fprint(w, "\nr.URL.Host :"+r.URL.Host)
	_, _ = fmt.Fprint(w, "\nr.Host:"+r.Host)
	_, _ = fmt.Fprint(w, "\nr.URL.RequestURI(): "+r.URL.RequestURI())
	_, _ = fmt.Fprint(w, "\nr.URL.Path: "+r.URL.Path)

}

func (ctrl controller) aik(w http.ResponseWriter, _ *http.Request) {
	_, _ = w.Write(ctrl.aikCert.Raw)
}

func (ctrl controller) bindingKey(w http.ResponseWriter, _ *http.Request) {
	_, _ = w.Write(ctrl.bindingKeyCert)
}

func (ctrl controller) getQuoteSignedWithNonce(nonce []byte, tagPresent bool, assetTag string) (*tamodel.TpmQuoteResponse, error) {
	// make a copy of the the quote so that we leave the original untouched
	hash := sha256.New()
	hash.Write(nonce)
	taNonce := hash.Sum(nil)

	if tagPresent && assetTag != "" {
		tag, err := base64.StdEncoding.DecodeString(assetTag)
		if err != nil {
			return nil, err
		}

		hash := sha256.New()
		hash.Write(taNonce)
		hash.Write(tag)
		taNonce = hash.Sum(nil)
	}

	// stitch together the quote
	fullQuoteLen := len(ctrl.quoteParts.infoPreNonceSha1) + len(taNonce) + len(ctrl.quoteParts.infoPostNonceSha1) + 256 + len(ctrl.quoteParts.afterSignature)
	newQuote := make([]byte, len(ctrl.quoteParts.infoPreNonceSha1), fullQuoteLen)
	copy(newQuote, ctrl.quoteParts.infoPreNonceSha1)
	newQuote = append(newQuote, taNonce...)
	newQuote = append(newQuote, ctrl.quoteParts.infoPostNonceSha1...)

	// sign it... have the ignore the first 2 bytes as well as the last 6 bytes
	// first 2 bytes are length of the quote - last 6 bytes are signature algorigthm,
	// signature hash algorithm and signature size...

	signHash := sha256.Sum256(newQuote[2 : len(newQuote)-6])
	signature, err := rsa.SignPKCS1v15(rand.Reader, ctrl.aikKey, crypto.SHA256, signHash[:])
	if err != nil {
		return nil, errors.Wrap(err, "Could not sign the file")
	}
	// append the signature
	newQuote = append(newQuote, signature...)

	// append the rest of the original quote after the signature
	newQuote = append(newQuote, ctrl.quoteParts.afterSignature...)

	// create a full quote from the saved contents... we do not want to overwrite the current on
	fullQuote := *ctrl.tpmQuote
	fullQuote.Quote = base64.StdEncoding.EncodeToString(newQuote)

	// adding delay to simulate the TPM response time delay from an actual host
	time.Sleep(time.Duration(ctrl.config.QuoteDelayMs) * time.Millisecond)
	return &fullQuote, nil
}

func (ctrl controller) quote(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		return
	}
	var req tamodel.TpmQuoteRequest
	dec := json.NewDecoder(r.Body)

	if err := dec.Decode(&req); err != nil || len(req.Nonce) == 0 {
		w.WriteHeader(http.StatusBadRequest)
		if err != nil {
			_, _ = w.Write([]byte("Could not unmarshal json body to token request structure"))
		} else {
			_, _ = w.Write([]byte("nonce cannot be empty in request"))
		}
		return
	}
	if qt, err := ctrl.getQuoteSignedWithNonce(req.Nonce, ctrl.tpmQuote.IsTagProvisioned, ctrl.tpmQuote.AssetTag); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte("could not creating quote response error: " + err.Error()))
	} else {
		quote, _ := xml.MarshalIndent(qt, "", "\t")
		_, _ = w.Write(quote)
	}
}

func (ctrl controller) info(w http.ResponseWriter, r *http.Request) {
	hostData := ctrl.hostInfo
	hostParts := strings.Split(r.Host, ":")

	port := 0
	if len(hostParts) == 2 {
		if res, err := strconv.Atoi(hostParts[1]); err == nil {
			port = res
		}
	}
	hostData.BiosName = fmt.Sprintf("%s-%d", hostData.BiosName, port%ctrl.config.DistinctFlavors)
	hostData.BiosVersion = fmt.Sprintf("%s-%d", hostData.BiosVersion, port%ctrl.config.DistinctFlavors)
	hostData.OSVersion = fmt.Sprintf("%s-%d", hostData.OSVersion, port%ctrl.config.DistinctFlavors)
	hostData.VMMName = fmt.Sprintf("%s-%d", hostData.VMMName, port%ctrl.config.DistinctFlavors)
	hostData.VMMVersion = fmt.Sprintf("%s-%d", hostData.VMMVersion, port%ctrl.config.DistinctFlavors)
	hostData.HostName = fmt.Sprintf("%s-%d", hostData.HostName, port)
	hostData.HardwareUUID = ctrl.hwUuidMap[port-ctrl.config.PortStart]

	jsonData, _ := json.Marshal(hostData)
	_, _ = w.Write(jsonData)
}

func startServers(ac *AppConfig) (err error) {

	var ctrl *controller
	if ctrl, err = NewController(ac); err != nil {
		return errors.Wrap(err, "Could not initialize controller")
	}

	if ac.TaSimServiceMode == communicationModeHttp {
		log.Info("Starting TA simulators in HTTP mode")
		// create `ServerMux`
		mux := http.NewServeMux()
		// create a default route handler
		mux.HandleFunc("/", ctrl.hello)
		mux.HandleFunc("/v2/aik", ctrl.aik)
		mux.HandleFunc("/v2/binding-key-certificate", ctrl.bindingKey)
		mux.HandleFunc("/v2/tpm/quote", ctrl.quote)
		mux.HandleFunc("/v2/host", ctrl.info)

		wg := new(sync.WaitGroup)
		// add number of Servers to `wg` WaitGroup
		wg.Add(ac.Servers)
		for i := ac.PortStart; i < ac.PortStart+ac.Servers; i++ {
			go func(port int) {
				// create new server
				server := http.Server{
					Addr:    fmt.Sprintf(":%v", port), // :{Port}
					Handler: mux,
				}
				server.SetKeepAlivesEnabled(false)
				log.Info(server.ListenAndServeTLS(ac.sslCertPath, ac.sslKeyPath))
				wg.Done()
			}(i)
		}
		wg.Wait()
	} else if ac.TaSimServiceMode == communicationModeOutbound {
		log.Info("Starting TA simulators in outbound mode")
		hwUuids, err := loadNSaveHwUuidFile(ac.hwUuidMapPath, ac.PortStart, ac.Servers)
		if err != nil {
			return err
		}
		wg := new(sync.WaitGroup)
		// add number of Servers to `wg` WaitGroup
		wg.Add(100)
		for i := 0; i < ac.Servers; i++ {
			go func(i int) {
				// create new server
				hvsSubscriber, err := NewHVSSubscriber(hwUuids[i], ac, *ctrl)
				if err != nil {
					log.Errorf("Error getting a new HVS Subscriber: %s", err.Error())
				}
				err = hvsSubscriber.Start()
				if err != nil {
					log.Errorf("HVS subcriber Error : %s", err.Error())
				}
				wg.Done()
			}(i)
		}
		wg.Wait()
	} else {
		return errors.New("Invalid TA simulator service mode, should be either http or outboud")
	}

	log.Infof("Started %d servers", ac.Servers)
	return nil
}

func getAuthToken(aasUrl, apiUser, apiPass string) (string, error) {
	tr := &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
	}
	client := http.Client{
		Timeout:   time.Duration(5 * time.Second),
		Transport: tr,
	}
	reqBody, err := json.Marshal(map[string]string{
		"username": apiUser,
		"password": apiPass,
	})
	req, err := http.NewRequest("POST", aasUrl+"token", bytes.NewBuffer(reqBody))
	if err != nil {
		return "", errors.Wrap(err, "could not create token request")
	}
	resp, err := client.Do(req)
	if err != nil {
		return "", errors.Wrap(err, "could not obtain token from aas")
	}
	defer resp.Body.Close()
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return "", errors.Wrap(err, "could not read token from aas")
	}
	return string(body), nil

}

func sendCreateHostRequest(hvsUrl, authtoken, ip, hw_uuid string, port int, client *http.Client, wg *sync.WaitGroup, serviceMode string) {
	defer wg.Done()

	connection_str := fmt.Sprintf("https://%s:%d", ip, port)
	if serviceMode == communicationModeOutbound {
		connection_str = fmt.Sprintf("intel:nats://%s", hw_uuid)
	}

	reqBody, err := json.Marshal(map[string]string{
		"host_name":         "Go-TASim-" + hw_uuid,
		"connection_string": connection_str,
	})

	req, err := http.NewRequest("POST", hvsUrl+"hosts", bytes.NewBuffer(reqBody))
	if err != nil {
		log.Error("could not create new request for creating host error : ", err)
		return
	}
	req.Header.Set("Authorization", "Bearer "+authtoken)
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Content-type", "application/json")
	resp, err := client.Do(req)
	if err != nil {
		log.Error("could not create new host"+fmt.Sprintf("https://%s:%d", ip, port), "error: ", err)
		return
	}
	defer resp.Body.Close()
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		log.Error("could not response from from hvs create host"+fmt.Sprintf("https://%s:%d", ip, port), "error:", err)
		return
	}
	if resp.StatusCode != 201 {
		log.Error("Host not created. Request : ", string(reqBody), "Response Code: ", resp.Status, " Response Data: ", string(body))
		return
	}
	log.Info("host created successfully. Response :" + string(body))

}

func sendCreateFlavorRequest(flavorParts []string, hvsUrl, authtoken, ip string, port int, client *http.Client, wg *sync.WaitGroup, hw_uuid, serviceMode string) {
	defer wg.Done()
	log.Info("Preparing request to create flavors ")

	connection_str := fmt.Sprintf("https://%s:%d", ip, port)
	if serviceMode == communicationModeOutbound {
		connection_str = fmt.Sprintf("intel:nats://%s", hw_uuid)
	}

	reqBody, err := json.Marshal(map[string]interface{}{
		"connection_string":    connection_str,
		"partial_flavor_types": flavorParts,
	})

	req, err := http.NewRequest("POST", hvsUrl+"flavors", bytes.NewBuffer(reqBody))
	if err != nil {
		log.Error("could not create new request for creating flavors - error : ", err)
		return
	}
	req.Header.Set("Authorization", "Bearer "+authtoken)
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Content-type", "application/json")
	resp, err := client.Do(req)
	if err != nil {
		log.Error("could not create new flavor", string(reqBody), "error: ", err)
		return
	}
	defer resp.Body.Close()
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		log.Error("could not read response from from hvs create flavor ", reqBody, "error:", err)
		return
	}
	if resp.StatusCode != 201 {
		log.Error("flavor not created. Response Code: ", resp.Status, "Response Data: ", string(body))
		return
	}
	log.Info("flavor created successfully. Response :" + string(body))

}

func registerHosts(ac *AppConfig) error {
	log.Info("Getting Authentication token to create hosts")
	authToken, err := getAuthToken(ac.AasApiUrl, ac.ApiUserName, ac.ApiUserPassword)
	if err != nil {
		return err
	}
	log.Info("Authentication token obtained successfully")

	hwUuids, err := loadNSaveHwUuidFile(ac.hwUuidMapPath, ac.PortStart, ac.Servers)
	if err != nil {
		return err
	}

	wg := new(sync.WaitGroup)
	tr := &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
	}
	client := http.Client{
		Timeout:   time.Duration(30 * time.Second),
		Transport: tr,
	}

	for i := ac.PortStart; i < ac.PortStart+ac.Servers; i++ {
		wg.Add(1)
		go sendCreateHostRequest(ac.HvsApiUrl, authToken, ac.SimulatorIP, hwUuids[i-ac.PortStart], i, &client, wg, ac.TaSimServiceMode)
		if (i+1)%ac.RequestVolume == 0 {
			time.Sleep(time.Duration(ac.RequestVolumeDelayMs) * time.Millisecond)
			wg.Wait()
		}
	}
	wg.Wait()
	log.Info("Create Hosts completed")
	return nil
}

func createFlavors(ac *AppConfig) error {
	log.Info("Getting Authentication token to create flavors")
	authToken, err := getAuthToken(ac.AasApiUrl, ac.ApiUserName, ac.ApiUserPassword)
	if err != nil {
		return err
	}
	log.Info("Authentication token obtained successfully")

	wg := new(sync.WaitGroup)
	trustedHosts := ac.Servers * ac.TrustedHostsPercentage / 100

	allFlavors := []string{"PLATFORM", "OS", "HOST_UNIQUE"}
	hostUniqueFlavors := []string{"HOST_UNIQUE"}
	hwUuids, err := loadNSaveHwUuidFile(ac.hwUuidMapPath, ac.PortStart, ac.Servers)
	if err != nil {
		return err
	}

	i := ac.PortStart

	tr := &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
	}
	client := http.Client{
		Timeout:   time.Duration(30 * time.Second),
		Transport: tr,
	}

	for ; i < ac.PortStart+trustedHosts && i < ac.PortStart+ac.DistinctFlavors; i++ {
		wg.Add(1)
		go sendCreateFlavorRequest(allFlavors, ac.HvsApiUrl, authToken, ac.SimulatorIP, i, &client, wg, hwUuids[i-ac.PortStart], ac.TaSimServiceMode)
		if (i+1)%ac.RequestVolume == 0 {
			time.Sleep(time.Duration(ac.RequestVolumeDelayMs) * time.Millisecond)
			wg.Wait()
		}
	}

	for ; i < ac.PortStart+trustedHosts; i++ {
		wg.Add(1)
		go sendCreateFlavorRequest(hostUniqueFlavors, ac.HvsApiUrl, authToken, ac.SimulatorIP, i, &client, wg, hwUuids[i-ac.PortStart], ac.TaSimServiceMode)
		if (i+1)%ac.RequestVolume == 0 {
			time.Sleep(time.Duration(ac.RequestVolumeDelayMs) * time.Millisecond)
			wg.Wait()
		}
	}
	wg.Wait()
	log.Info("Create Flavors completed")
	return nil

}

func createBindingKeyCertMain(ac *AppConfig) error {

	if len(os.Args) < 4 {
		return errors.New("can't parse cli flags")
	}
	configDir := filepath.Dir(ac.aikCertPath)
	pcaKeyPath := filepath.Join(configDir, "pca-key")
	pcaCertPath := filepath.Join(configDir, "pca-cert")
	for _, arg := range os.Args[2:] {
		split := strings.Split(arg, "=")
		if len(split) < 2 {
			return errors.New("invalid cli argument: " + arg)
		}
		switch flag, val := split[0], split[1]; flag {
		case "--pca-key":
			pcaKeyPath = val
		case "--pca-cert":
			pcaCertPath = val
		}
	}
	// load aik key
	aikCert, aikPrivateKey, err := crypt.LoadX509CertAndPrivateKey(ac.aikCertPath, ac.aikKeyPath)
	if err != nil {
		return errors.Wrap(err, "failed to parse aik cert and key")
	}

	aikRSAKey, ok := aikPrivateKey.(*rsa.PrivateKey)
	if !ok {
		return errors.Wrap(err, "aik Private Key is not an expected RSA key ")
	}

	pcaCert, pcaPrivateKey, err := crypt.LoadX509CertAndPrivateKey(pcaCertPath, pcaKeyPath)
	if err != nil {
		return errors.Wrap(err, "failed to load Privacy CA cer and key")
	}

	if _, ok := pcaPrivateKey.(*rsa.PrivateKey); !ok {
		return errors.Wrap(err, "Privacy Key is not of type RSA")
	}

	// generate binding key and cert
	bindingKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		return errors.Wrap(err, "failed to generate binding key:")
	}

	rki, err := generateRegisterKeyInfo(aikRSAKey, bindingKey, aikCert.Raw)
	if err != nil {
		return errors.Wrap(err, "failed to generate RegisterKeyInfo:")
	}
	bindingKeyCertBytes, err := createBindingKeyCert(pcaPrivateKey, pcaCert, "binding-key", rki)
	if err != nil {
		return errors.Wrap(err, "failed to create BindingKeyCert:")
	}
	// save binding key and cert to file

	bindingKeyByte, err := x509.MarshalPKCS8PrivateKey(bindingKey)
	err = crypt.SavePrivateKeyAsPKCS8(bindingKeyByte, ac.bindingKeyPath+".key")
	if err != nil {
		return errors.Wrap(err, "failed to create binding key file")
	}
	err = crypt.SavePemCert(bindingKeyCertBytes, ac.bindingKeyPath)
	if err != nil {
		return errors.Wrap(err, "failed to create binding key file")
	}
	return nil
}

func main() {

	var ac *AppConfig
	var err error
	if len(os.Args) > 1 && strings.ToLower(os.Args[1]) == "version" {
		fmt.Printf("Go Trust Agent Simulator %s-%s\nBuilt %s\n", Version, GitHash, BuildDate)
		return
	}

	if ac, err = getApplicationData(); err != nil {
		log.Error("could not load application data - Error : ", err)
		os.Exit(1)
	}
	action := "help"
	if len(os.Args) > 1 {
		action = os.Args[1]
	}

	switch action {

	case "start":
		if err := startServers(ac); err != nil {
			log.Error(err)
			os.Exit(1)
		}
	case "create-all-flavors":
		if err := createFlavors(ac); err != nil {
			log.Error("could not create flavors - Error : ", err)
			os.Exit(1)
		}

	case "create-all-hosts":
		if err := registerHosts(ac); err != nil {
			log.Error("could not register - Error : ", err)
			os.Exit(1)
		}

	case "create-binding-key-cert":
		if err := createBindingKeyCertMain(ac); err != nil {
			log.Error("could not create binding key cert : ", err)
			os.Exit(1)
		}

	case "get-host-data-from-nats":
		if err := getHostData(ac); err != nil {
			log.Error("could not download host-info and tpm-quote from TA : ", err)
			fmt.Printf("Error occured while getting TA data :\n %+v\n", err)
			os.Exit(1)
		}

	case "help", "--help", "-h":
		fmt.Printf("Go Trust Agent Simulator %s-%s\tBuilt %s", Version, GitHash, BuildDate)
		fmt.Println("Usage")
		fmt.Printf("\n\t %s start | create-all-flavors | create-all-hosts | create-binding-key-cert ", os.Args[0])
		fmt.Printf("\n\n\t create-binding-key-cert Usage")
		fmt.Printf("\n\t %s create-binding-key-cert --pca-cert=<path_to_privacy_ca_cert> --pca-key=<path_to_privacy_ca_key>", os.Args[0])
		fmt.Println("\n create-all-flavors and create-all-host require that start is called and process is running in background ")
	}
}

func getHostData(ac *AppConfig) error {

	// tls configuration with disabled server certificate chain verification
	tlsConfig := &tls.Config{
		InsecureSkipVerify: true,
	}
	// get TA client
	taClient, err := client.NewNatsTAClient(ac.NatsServers, ac.TaHostId, tlsConfig, ac.natsTaSubCredentialsPath)
	if err != nil {
		return errors.Wrap(err, "Could not create Nats Trust Agent client")
	}

	hostInfo, err := taClient.GetHostInfo()
	if err != nil {
		return errors.Wrapf(err, "Error getting host-info from TA with HostId %s", ac.TaHostId)
	}
	taHostInfo, _ := json.Marshal(hostInfo)
	err = ioutil.WriteFile(ac.hostInfoPath, taHostInfo, 0644)
	if err != nil {
		return errors.Wrapf(err, "Error writing host-info to file %s", ac.hostInfoPath)
	}

	nonce := "+c4ZEmco4aj1G5dTXQvjIMGFd44="
	pcrList := []int{0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23}
	pcrbanks := []string{"SHA1", "SHA256", "SHA384"}

	quote, err := taClient.GetTPMQuote(nonce, pcrList, pcrbanks)
	if err != nil {
		return errors.Wrapf(err, "Error getting host-info from TA with HostId %s", ac.TaHostId)
	}
	tpmQuote, err := xml.Marshal(quote)
	if err != nil {
		return errors.Wrap(err, "Error marshalling tpm-quote")
	}
	err = ioutil.WriteFile(ac.tpmQuotePath, tpmQuote, 0644)
	if err != nil {
		return errors.Wrapf(err, "Error writing tpm-quote to file %s", ac.tpmQuotePath)
	}
	return nil
}
