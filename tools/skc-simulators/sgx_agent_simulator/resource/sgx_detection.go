/*
 * Copyright (C) 2020 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */

package resource

import (
	"bytes"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"github.com/klauspost/cpuid"
	"github.com/pkg/errors"
	"intel/isecl/lib/clients/v4"
	clog "intel/isecl/lib/common/v4/log"
	"intel/isecl/sgx_agent/v4/config"
	"intel/isecl/sgx_agent/v4/constants"
	"intel/isecl/sgx_agent/v4/utils"
	"io/ioutil"
	"net/http"
	"os"
	"strconv"
	"time"
)

// MSR.IA32_Feature_Control register tells availability of SGX
const (
	FeatureControlRegister = 0x3A
	MSRDevice              = "/dev/cpu/0/msr"
)

var log = clog.GetDefaultLogger()
var slog = clog.GetSecurityLogger()

type SGXDiscoveryData struct {
	SgxSupported        bool   `json:"sgx-supported"`
	SgxEnabled          bool   `json:"sgx-enabled"`
	FlcEnabled          bool   `json:"flc-enabled"`
	EpcStartAddress     string `json:"epc-offset"`
	EpcSize             string `json:"epc-size"`
	sgxInstructionSet   int
	maxEnclaveSizeNot64 int64
	maxEnclaveSize64    int64
}

type PlatformData struct {
	EncryptedPPID string `json:"enc-ppid"`
	PceID         string `json:"pceid"`
	CPUSvn        string `json:"cpusvn"`
	PceSvn        string `json:"pcesvn"`
	QeID          string `json:"qeid"`
	Manifest      string `json:"Manifest"`
}

var (
	pckIDRetrievalInfo = []string{"PCKIDRetrievalTool", "-f", constants.PCKDataFile}
)

type SCSPushResponse struct {
	Status  string `json:"Status"`
	Message string `json:"Message"`
}

var sgxData SGXDiscoveryData
var platformData PlatformData

func ExtractSGXPlatformValues(id int) (*SGXDiscoveryData, *PlatformData, error) {
	var sgxEnablementInfo *SGXDiscoveryData
	var sgxPlatformData *PlatformData
	id_str := strconv.Itoa(id)
	log.Info("SGX Extensions are enabled, hence proceeding further")
	sgxData.SgxSupported = true
	sgxData.SgxEnabled = true
	sgxData.FlcEnabled = true
	sgxData.EpcStartAddress = "0x7020" + id_str
	sgxData.EpcSize = "189.5" + id_str + " MB"
	platformData.PceID = "0000"
	platformData.CPUSvn = "0202ffffff8002000000010000000000"
	platformData.PceSvn = "0a00"
	sgxData.EpcStartAddress = "0x7020" + id_str
	sgxData.EpcSize = "189.5" + id_str + " MB"
	for len(id_str) < 6 {
		id_str = "0" + id_str
	}

	platformData.EncryptedPPID = "d029c0e96cbcd22918f54329b89ec624eb851860395f56dd88125013ca4651e6f263e925c3f40ad2b498697583effffe55ee641c4f3fd3ffce963e86a6d3b830a833b48a5714bd4229612c2f92c62c7becd6b0e39e5b830b95f484b3c23a3c4d1eb3f8ea0e6978e50151853baba19a2b58ecda921b5eb2b92524e158960f068ece55da722cc6d166e44b2ee0a6cebf9733bf2f3df46016373d14b5ec7e1b270d99aaa06cc38112adc7259a86ef4965907832933c2258cfefee165fd64dddea283ab9f6864639bf58c240de57746ae7e62ddd1917978bce6f42dd39e8ab733b58037dcc2230c0a873d5d0f257c714e8b05133879e1f4422427872c99715dfd5bf82325d4d0307347a3f36b21f58e96f73311f88cb207dc1bd4bafe444b23988641c9c7f45905c6b7c902d5841a07b2360a24010108beb7ec809941909b45375b51afa0626af7733c7eb4144cbc08cb4fb47477c1193955844263cae04c6b6e93be0992c157aa08866a56262746cb8c9e65787ce8d649cc2cb0d939f42ffec937a"
	platformData.QeID = "bf2b" + id_str + "b1bb879a788a1c104f67ff"
	platformData.Manifest = "qwertyuiopasdfghjklzxcvbnmqwertyuiopasdfghjklzxcvbnmqwertyuiopasdfghjklzxcvbnmqwertyuiopasdfghjklzxcvbnmqwertyuiopasdfghjklzxcvbnmqwertyuiopasdfghjklzxcvbnmqwertyuiopasdfghjklzxcvbnmqwertyuiopasdfghjklzxcvbnmqwertyuiopasdfghjklzxcvbnmqwertyuiopasdfghjklzxcvbnmqwertyuiopasdfghjklzxcvbnmqwertyuiopasdfghjklzxcvbnm"
	sgxEnablementInfo = &sgxData
	sgxPlatformData = &platformData
	return sgxEnablementInfo, sgxPlatformData, nil
}

// ReadMSR is a utility function that reads an 64 bit value from /dev/cpu/0/msr at offset 'offset'
func ReadMSR(offset int64) (uint64, error) {

	msr, err := os.Open(MSRDevice)
	if err != nil {
		return 0, errors.Wrapf(err, "sgx_detection:ReadMSR(): Error opening msr")
	}

	_, err = msr.Seek(offset, 0)
	if err != nil {
		return 0, errors.Wrapf(err, "sgx_detection:ReadMSR(): Could not seek to location %x", offset)
	}

	results := make([]byte, 8)
	readLen, err := msr.Read(results)
	if err != nil {
		return 0, errors.Wrapf(err, "sgx_detection:ReadMSR(): There was an error reading msr at offset %x", offset)
	}
	if readLen < 8 {
		return 0, errors.New("sgx_detection:ReadMSR(): Reading the msr returned the incorrect length")
	}

	err = msr.Close()
	if err != nil {
		return 0, errors.Wrapf(err, "sgx_detection:ReadMSR(): Error while closing msr device file")
	}
	return binary.LittleEndian.Uint64(results), nil
}

func isSGXAndFLCEnabled() (sgxEnabled, flcEnabled bool, err error) {
	sgxEnabled = false
	flcEnabled = false
	sgxBits, err := ReadMSR(FeatureControlRegister)
	if err != nil {
		return sgxEnabled, flcEnabled, errors.Wrap(err, "Error while reading MSR")
	}

	// check if SGX is enabled or not
	if (sgxBits&(1<<18) != 0) && (sgxBits&(1<<0) != 0) {
		sgxEnabled = true
	}

	// check if FLC is enabled or not
	if (sgxBits&(1<<17) != 0) && (sgxBits&(1<<0) != 0) {
		flcEnabled = true
	}
	return sgxEnabled, flcEnabled, nil
}

func cpuid_low(arg1, arg2 uint32) (eax, ebx, ecx, edx uint32)

func isCPUSupportsSGXExtensions() bool {
	sgxExtensionsEnabled := false
	_, ebx, _, _ := cpuid_low(7, 0)
	if ((ebx >> 2) & 1) != 0 { // 2nd bit should be set if SGX extensions are supported.
		sgxExtensionsEnabled = true
	}
	return sgxExtensionsEnabled
}

func epcMemoryDetails() (epcOffset, epcSize string) {
	eax, ebx, ecx, edx := cpuid_low(18, 2)
	log.Debugf("eax, ebx, ecx, edx: %08x-%08x-%08x-%08x", eax, ebx, ecx, edx)
	// eax(31, 12) + ebx(51, 32)
	range1 := uint64((((1 << 20) - 1) & (eax >> 12)))
	range2 := uint64(((1 << 20) - 1) & ebx)
	startAddress := (range2 << 32) | (range1 << 12)
	log.Debugf("startaddress: %08x", startAddress)

	// ecx(31, 12) + edx(51, 32)
	range1 = uint64(((1 << 20) - 1) & (ecx >> 12))
	range2 = uint64(((1 << 20) - 1) & edx)
	size := (range2 << 32) | (range1 << 12)
	sizeINMB := convertToMB(size)
	startAddressinHex := "0x" + fmt.Sprintf("%08x", startAddress)
	log.Debugf("size in decimal %20d  and mb %16q: ", size, sizeINMB)
	return startAddressinHex, sizeINMB
}

func isSGXInstructionSetSuported() int {
	cpuid.Detect()
	sgxInstructionSet := 0
	if cpuid.CPU.SGX.SGX1Supported {
		sgxInstructionSet = 1
		if cpuid.CPU.SGX.SGX2Supported {
			sgxInstructionSet = 2
		}
	} else {
		log.Debug("SGX instruction set 1 and 2 are not supported.")
	}
	return sgxInstructionSet
}

func maxEnclaveSize() (maxSizeNot64, maxSize64 int64) {
	cpuid.Detect()
	return cpuid.CPU.SGX.MaxEnclaveSizeNot64, cpuid.CPU.SGX.MaxEnclaveSize64
}

func runPCKIDRetrivalInfo() error {
	// Output is written to /opt/pckData
	// FIXME : Check the error messages.
	log.Debug("Running PCKIDRetrival tool and write to cache...")
	_, err := utils.ReadAndParseFromCommandLine(pckIDRetrievalInfo)
	if err != nil {
		return err
	}

	return nil
}

func isPCKDataCached() bool {
	log.Debug("Checking if PCK Data was cached... ")

	if _, err := os.Stat(constants.PCKDataFile); err == nil {
		log.Debug("PCK Data is available in cache.")
		return true
	}

	log.Debug("PCK Data is not cached. ")

	return false
}

func writePCKData(fileContents string) error {
	// path/to/whatever exists
	err := ioutil.WriteFile(constants.PCKDataFile, []byte(fileContents), 0644)
	if err != nil {
		log.Error("Could not write sgx platform values to pckData file")
	}

	return err
}

func readPCKDetailsFromCache() (string, error) {
	log.Debug("Reading PCKDetails from cache ... ")
	fileContents := ""

	// Check if file exists in the directory then parse it and write the values in log file.
	_, err := os.Stat(constants.PCKDataFile)
	if err == nil {
		// path/to/whatever exists
		dat, err := ioutil.ReadFile(constants.PCKDataFile)
		if err != nil {
			log.Error("could not read sgx platform values from pckData file")
		} else {
			fileContents = string(dat)
		}
	} else if os.IsNotExist(err) {
		// path/to/whatever does *not* exist
		log.Warning("pckData file not found.")
	} else {
		log.Warning("Unknown error while reading pckData file")
	}
	return fileContents, err
}

func convertToMB(b uint64) string {
	const unit = 1024
	if b < unit {
		return fmt.Sprintf("%d B", b)
	}
	div, exp := int64(unit), 0
	for n := b / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %cB",
		float64(b)/float64(div), "kMGTPE"[exp])
}

func PushSGXData(pdata *PlatformData, hardwareUUID string) (bool, error) {
	log.Trace("resource/sgx_detection.go: PushSGXData() Entering")
	defer log.Trace("resource/sgx_detection.go: PushSGXData() Leaving")
	client, err := clients.HTTPClientWithCADir(constants.TrustedCAsStoreDir)
	if err != nil {
		return false, errors.Wrap(err, "PushSGXData: Error in getting client object")
	}

	conf := config.Global()
	if conf == nil {
		return false, errors.Wrap(errors.New("PushSGXData: Configuration pointer is null"), "Config error")
	}

	pushURL := conf.ScsBaseURL + "/certification/v1/platforms"
	log.Debug("PushSGXData: URL: ", pushURL)
	for i := conf.HostStartId; i < conf.HostStartId+conf.NumberOfHosts; i++ {
		ExtractSGXPlatformValues(i)
		requestStr := map[string]string{
			"enc_ppid":      pdata.EncryptedPPID,
			"cpu_svn":       pdata.CPUSvn,
			"pce_svn":       pdata.PceSvn,
			"pce_id":        pdata.PceID,
			"qe_id":         pdata.QeID,
			"manifest":      pdata.Manifest,
			"hardware_uuid": hardwareUUID}

		reqBytes, err := json.Marshal(requestStr)

		if err != nil {
			return false, errors.Wrap(err, "PushSGXData: Marshal error:"+err.Error())
		}

		req, err := http.NewRequest("POST", pushURL, bytes.NewBuffer(reqBytes))
		if err != nil {
			return false, errors.Wrap(err, "PushSGXData: Failed to Get New request")
		}

		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+conf.BearerToken)

		tokenExpired, err := utils.JwtHasExpired(conf.BearerToken)
		if err != nil {
			slog.WithError(err).Error("PushSGXData: Error verifying token expiry")
			return false, errors.Wrap(err, "PushSGXData: Error verifying token expiry")
		}
		if tokenExpired {
			slog.Warn("PushSGXData: Token is about to expire within 7 days. Please refresh the token.")
		}

		var retries = 0
		var timeBwCalls = conf.WaitTime
		resp, err := client.Do(req)
		if err != nil || (resp != nil && resp.StatusCode >= http.StatusInternalServerError) {

			for {
				log.Errorf("Retrying for '%d'th time: ", retries)
				req.Body = ioutil.NopCloser(bytes.NewBuffer(reqBytes))
				resp, err = client.Do(req)

				if resp != nil && resp.StatusCode < http.StatusInternalServerError {
					log.Info("PushSGXData: Status code received: " + strconv.Itoa(resp.StatusCode))
					log.Debug("PushSGXData: Retry count now: " + strconv.Itoa(retries))
					break
				}

				if err != nil {
					log.WithError(err).Info("PushSGXData:")
				}

				if resp != nil {
					log.Error("PushSGXData: Invalid status code received: " + strconv.Itoa(resp.StatusCode))
				}

				retries++
				if retries >= conf.RetryCount {
					log.Errorf("PushSGXData: Retried %d times, Sleeping %d minutes...", conf.RetryCount, timeBwCalls)
					time.Sleep(time.Duration(timeBwCalls) * time.Minute)
					retries = 0
				}

			}
		}

		if resp != nil && resp.StatusCode != http.StatusCreated && resp.StatusCode != http.StatusOK {
			err = resp.Body.Close()
			if err != nil {
				log.WithError(err).Error("Error closing response")
			}
			return false, errors.New("PushSGXData: Invalid status code received: " + strconv.Itoa(resp.StatusCode))
		}

		var pushResponse SCSPushResponse

		dec := json.NewDecoder(resp.Body)
		dec.DisallowUnknownFields()

		err = dec.Decode(&pushResponse)
		if err != nil {
			return false, errors.Wrap(err, "PushSGXData: Read Response failed")
		}

		log.Debug("PushSGXData: Received SCS Response Data: ", pushResponse)
		err = resp.Body.Close()
		if err != nil {
			log.WithError(err).Error("Error closing response")
		}
	}
	return true, nil
}
