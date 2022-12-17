/*
 * Copyright (C) 2020 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package main

import (
	"flag"
	"fmt"
	"github.com/google/uuid"
	"github.com/pkg/errors"
	e "intel/isecl/lib/common/v4/exec"
	commLog "intel/isecl/lib/common/v4/log"
	commLogMsg "intel/isecl/lib/common/v4/log/message"
	commLogInt "intel/isecl/lib/common/v4/log/setup"
	cos "intel/isecl/lib/common/v4/os"
	"intel/isecl/lib/common/v4/setup"
	"intel/isecl/sgx_agent/v4/config"
	"intel/isecl/sgx_agent/v4/constants"
	"intel/isecl/sgx_agent/v4/resource"
	"intel/isecl/sgx_agent/v4/tasks"
	"intel/isecl/sgx_agent/v4/utils"
	"intel/isecl/sgx_agent/v4/version"
	"io"
	"os"
	"os/exec"
	"os/user"
	"strconv"
	"strings"
	"time"
)

var log = commLog.GetDefaultLogger()
var slog = commLog.GetSecurityLogger()

type App struct {
	HomeDir        string
	ConfigDir      string
	LogDir         string
	ExecutablePath string
	ExecLinkPath   string
	RunDirPath     string
	Config         *config.Configuration
	ConsoleWriter  io.Writer
	LogWriter      io.Writer
	HTTPLogWriter  io.Writer
	SecLogWriter   io.Writer
}

var (
	hardwareUUIDCmd = []string{"dmidecode", "-s", "system-uuid"}
)

func (a *App) printUsage() {
	w := a.consoleWriter()
	fmt.Fprintln(w, "Usage:")
	fmt.Fprintln(w, "")
	fmt.Fprintln(w, "    sgx_agent <command> [arguments]")
	fmt.Fprintln(w, "")
	fmt.Fprintln(w, "Available Commands:")
	fmt.Fprintln(w, "    help|-h|--help        Show this help message")
	fmt.Fprintln(w, "    setup [task]          Run setup task")
	fmt.Fprintln(w, "    start                 Start sgx_agent")
	fmt.Fprintln(w, "    status                Show the status of sgx_agent")
	fmt.Fprintln(w, "    stop                  Stop sgx_agent")
	fmt.Fprintln(w, "    uninstall             Uninstall sgx_agent")
	fmt.Fprintln(w, "    version|--version|-v  Show the version of sgx_agent")
	fmt.Fprintln(w, "")
	fmt.Fprintln(w, "Available Tasks for setup:")
	fmt.Fprintln(w, "    all                       Runs all setup tasks")
	fmt.Fprintln(w, "                              Required env variables:")
	fmt.Fprintln(w, "                                  - get required env variables from all the setup tasks")
	fmt.Fprintln(w, "                              Optional env variables:")
	fmt.Fprintln(w, "                                  - get optional env variables from all the setup tasks")
	fmt.Fprintln(w, "")
	fmt.Fprintln(w, "    update_service_config    Updates Service Configuration")
	fmt.Fprintln(w, "                             Required env variables:")
	fmt.Fprintln(w, "                                 - SCS_BASE_URL                                     : SCS Base URL")
	fmt.Fprintln(w, "                                 - SGX_AGENT_LOGLEVEL                               : SGX_AGENT Log Level")
	fmt.Fprintln(w, "                                 - SGX_AGENT_LOG_MAX_LENGTH                         : SGX Agent Log maximum length")
	fmt.Fprintln(w, "                                 - SGX_AGENT_ENABLE_CONSOLE_LOG                     : SGX Agent Enable standard output")
	fmt.Fprintln(w, "                                 - SHVS_UPDATE_INTERVAL                             : SHVS update interval in minutes")
	fmt.Fprintln(w, "                                 - WAIT_TIME                                        : Time between each retries to PCS")
	fmt.Fprintln(w, "                                 - RETRY_COUNT                                      : Push Data Retry Count to SCS")
	fmt.Fprintln(w, "                                 - SHVS_BASE_URL                                    : HVS Base URL")
	fmt.Fprintln(w, "                                 - BEARER_TOKEN                                     : BEARER TOKEN")
	fmt.Fprintln(w, "")
	fmt.Fprintln(w, "    download_ca_cert         Download CMS root CA certificate")
	fmt.Fprintln(w, "                             - Option [--force] overwrites any existing files, and always downloads new root CA cert")
	fmt.Fprintln(w, "                             Required env variables specific to setup task are:")
	fmt.Fprintln(w, "                                 - CMS_BASE_URL=<url>                                : for CMS API url")
	fmt.Fprintln(w, "                                 - CMS_TLS_CERT_SHA384=<CMS TLS cert sha384 hash>    : to ensure that SGX-Agent is talking to the right CMS instance")
	fmt.Fprintln(w, "")
}

func (a *App) consoleWriter() io.Writer {
	if a.ConsoleWriter != nil {
		return a.ConsoleWriter
	}
	return os.Stdout
}

func (a *App) logWriter() io.Writer {
	if a.LogWriter != nil {
		return a.LogWriter
	}
	return os.Stderr
}

func (a *App) secLogWriter() io.Writer {
	if a.SecLogWriter != nil {
		return a.SecLogWriter
	}
	return os.Stdout
}

func (a *App) configuration() *config.Configuration {
	if a.Config != nil {
		return a.Config
	}
	return config.Global()
}

func (a *App) executablePath() string {
	if a.ExecutablePath != "" {
		return a.ExecutablePath
	}
	execPath, err := os.Executable()
	if err != nil {
		log.WithError(err).Error("app:executablePath() Unable to find SGX_AGENT executable")
		// if we can't find self-executable path, we're probably in a state that is panic() worthy
		panic(err)
	}
	return execPath
}

func (a *App) homeDir() string {
	if a.HomeDir != "" {
		return a.HomeDir
	}
	return constants.HomeDir
}

func (a *App) configDir() string {
	if a.ConfigDir != "" {
		return a.ConfigDir
	}
	return constants.ConfigDir
}

func (a *App) logDir() string {
	if a.LogDir != "" {
		return a.ConfigDir
	}
	return constants.LogDir
}

func (a *App) execLinkPath() string {
	if a.ExecLinkPath != "" {
		return a.ExecLinkPath
	}
	return constants.ExecLinkPath
}

func (a *App) runDirPath() string {
	if a.RunDirPath != "" {
		return a.RunDirPath
	}
	return constants.RunDirPath
}

func (a *App) configureLogs(stdOut, logFile bool) {

	var ioWriterDefault io.Writer
	ioWriterDefault = a.LogWriter

	if stdOut {
		if logFile {
			ioWriterDefault = io.MultiWriter(os.Stdout, a.logWriter())
		} else {
			ioWriterDefault = os.Stdout
		}
	}

	ioWriterSecurity := io.MultiWriter(ioWriterDefault, a.secLogWriter())
	f := commLog.LogFormatter{MaxLength: a.configuration().LogMaxLength}
	commLogInt.SetLogger(commLog.DefaultLoggerName, a.configuration().LogLevel, &f, ioWriterDefault, false)
	commLogInt.SetLogger(commLog.SecurityLoggerName, a.configuration().LogLevel, &f, ioWriterSecurity, false)

	slog.Info(commLogMsg.LogInit)
	log.Info(commLogMsg.LogInit)
}

func (a *App) Run(args []string) error {
	if len(args) < 2 {
		a.printUsage()
		os.Exit(1)
	}

	cmd := args[1]
	switch cmd {
	default:
		a.printUsage()
		fmt.Fprintf(os.Stderr, "Unrecognized command: %s\n", args[1])
		os.Exit(1)
	case "run":
		a.configureLogs(a.configuration().LogEnableStdout, true)
		if err := a.startAgent(); err != nil {
			fmt.Fprintln(os.Stderr, "Error: daemon did not start - ", err.Error())
			// wait some time for logs to flush - otherwise, there will be no entry in syslog
			time.Sleep(5 * time.Millisecond)
			return errors.Wrap(err, "app:Run() Error starting SGX Agent service")
		}
	case "help", "-h", "--help":
		a.printUsage()
		return nil
	case "start":
		a.configureLogs(a.configuration().LogEnableStdout, true)
		return a.start()
	case "stop":
		a.configureLogs(a.configuration().LogEnableStdout, true)
		return a.stop()
	case "status":
		a.configureLogs(a.configuration().LogEnableStdout, true)
		return a.status()
	case "uninstall":
		var purge bool
		flag.CommandLine.BoolVar(&purge, "purge", false, "purge config when uninstalling")
		err := flag.CommandLine.Parse(args[2:])
		if err != nil {
			return err
		}
		a.uninstall(purge)
		log.Info("app:Run() Uninstalled SGX Agent Service")
		os.Exit(0)
	case "version", "--version", "-v":
		fmt.Println(version.GetVersion())
	case "setup":
		a.configureLogs(a.configuration().LogEnableStdout, true)
		var context setup.Context
		if len(args) <= 2 {
			a.printUsage()
			log.Error("app:Run() Invalid command")
			os.Exit(1)
		}
		if args[2] != "download_ca_cert" &&
			args[2] != "update_service_config" &&
			args[2] != "all" {
			a.printUsage()
			return errors.New("No such setup task")
		}
		validErr := validateSetupArgs(args[2], args[3:])
		if validErr != nil {
			return errors.Wrap(validErr, "app:Run() Invalid setup task arguments")
		}

		taskName := args[2]
		a.Config = config.Global()
		err := a.Config.SaveConfiguration(taskName, context)
		if err != nil {
			fmt.Println("Error saving configuration: " + err.Error())
			os.Exit(1)
		}
		task := strings.ToLower(args[2])

		setupRunner := &setup.Runner{
			Tasks: []setup.Task{
				setup.Download_Ca_Cert{
					Flags:                args,
					CmsBaseURL:           a.Config.CMSBaseURL,
					CaCertDirPath:        constants.TrustedCAsStoreDir,
					TrustedTlsCertDigest: a.Config.CmsTLSCertDigest,
					ConsoleWriter:        os.Stdout,
				},
				tasks.Update_Service_Config{
					Flags:         args,
					Config:        a.configuration(),
					ConsoleWriter: os.Stdout,
				},
			},
			AskInput: false,
		}

		if task == "all" {
			err = setupRunner.RunTasks()
		} else {
			err = setupRunner.RunTasks(task)
		}
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error running setup: %s\n", err)
			return err
		}

		if _, err := os.Stat("/.container-env"); err == nil {
			return nil
		}

		sgxAgentUser, err := user.Lookup(constants.SGXAgentUserName)
		if err != nil {
			return errors.Wrapf(err, "Could not find user '%s'", constants.SGXAgentUserName)
		}

		uid, err := strconv.Atoi(sgxAgentUser.Uid)
		if err != nil {
			return errors.Wrapf(err, "Could not parse sgx-agent user uid '%s'", sgxAgentUser.Uid)
		}

		gid, err := strconv.Atoi(sgxAgentUser.Gid)
		if err != nil {
			return errors.Wrapf(err, "Could not parse sgx-agent user gid '%s'", sgxAgentUser.Gid)
		}

		// Change the file ownership to sgx-agent user
		err = cos.ChownR(constants.ConfigDir, uid, gid)
		if err != nil {
			return errors.Wrap(err, "Error while changing file ownership")
		}

	}
	return nil
}

func (a *App) startAgent() error {
	log.Trace("app:startAgent() Entering")
	defer log.Trace("app:startAgent() Leaving")

	log.Info("Starting SGX Agent...")

	c := a.configuration()

	sgxDiscoveryData, platformData, err := resource.ExtractSGXPlatformValues(0)
	if err != nil {
		log.WithError(err).Error("Unable to extract SGX Platform Values. Terminating...")
		return err
	}

	// Get Hardware UUID
	result, err := utils.ReadAndParseFromCommandLine(hardwareUUIDCmd)
	if err != nil {
		return errors.Wrap(err, "Could not parse hardware UUID. Terminating...")
	}
	hardwareUUID := ""
	for i := range result {
		hardwareUUID = strings.TrimSpace(result[i])
		_, err = uuid.Parse(hardwareUUID)
		if err != nil {
			return errors.Wrap(err, "Hardware UUID is not in UUID format. Terminating...")
		}
		break
	}

	// Check if SGX Supported && SGX Enabled && FLC Enabled.
	if !sgxDiscoveryData.SgxSupported {
		err := errors.New("SGX is not supported.")
		log.WithError(err).Error("SGX is not supported. Terminating...")
		return err
	}
	log.Debug("SGX is supported.")

	if !sgxDiscoveryData.SgxEnabled {
		err := errors.New("SGX is not enabled.")
		log.WithError(err).Error("SGX is not enabled. Terminating...")
		return err
	}
	log.Debug("SGX is enabled.")

	if !sgxDiscoveryData.FlcEnabled {
		err := errors.New("FLC is not enabled.")
		log.WithError(err).Error("FLC is not enabled. Terminating...")
		return err
	}
	log.Debug("FLC is enabled.")

	status, err := resource.PushSGXData(platformData, hardwareUUID)
	if !status && err != nil {
		log.WithError(err).Error("Unable to push platform data to SCS. Terminating...")
		return err
	}

	// If SHVS URL is configured, get the tcbstatus from SCS and Push to SHVS periodically
	if c.SGXHVSBaseURL != "" {
		log.Info("SHVS URL is configured...")
		log.Debug("SHVS Update Interval is : ", c.SHVSUpdateInterval)

		// Start SHVS Update Beacon
		err = resource.UpdateSHVSPeriodically(sgxDiscoveryData, platformData, hardwareUUID, c.SHVSUpdateInterval)

		if err != nil {
			log.WithError(err).Error("Unable to update SHVS. Terminating...")
			return err
		}
	}
	slog.Info(commLogMsg.ServiceStop)
	return nil
}

func (a *App) start() error {
	log.Trace("app:start() Entering")
	defer log.Trace("app:start() Leaving")

	fmt.Fprintln(a.consoleWriter(), `Forwarding to "systemctl start sgx_agent"`)
	systemctl, err := exec.LookPath("systemctl")
	if err != nil {
		return err
	}
	cmd := exec.Command(systemctl, "start", "sgx_agent")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = os.Environ()
	return cmd.Run()
}

func (a *App) stop() error {
	log.Trace("app:stop() Entering")
	defer log.Trace("app:stop() Leaving")

	fmt.Fprintln(a.consoleWriter(), `Forwarding to "systemctl stop sgx_agent"`)
	systemctl, err := exec.LookPath("systemctl")
	if err != nil {
		return err
	}
	cmd := exec.Command(systemctl, "stop", "sgx_agent")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = os.Environ()
	return cmd.Run()
}

func (a *App) status() error {
	log.Trace("app:status() Entering")
	defer log.Trace("app:status() Leaving")

	fmt.Fprintln(a.consoleWriter(), `Forwarding to "systemctl status sgx_agent"`)
	systemctl, err := exec.LookPath("systemctl")
	if err != nil {
		return err
	}
	cmd := exec.Command(systemctl, "status", "sgx_agent")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = os.Environ()
	return cmd.Run()
}

func (a *App) uninstall(purge bool) {
	log.Trace("app:uninstall() Entering")
	defer log.Trace("app:uninstall() Leaving")

	fmt.Println("Uninstalling SGX Service")
	removeService()

	fmt.Println("removing : ", a.executablePath())
	err := os.Remove(a.executablePath())
	if err != nil {
		log.WithError(err).Error("error removing executable")
	}

	fmt.Println("removing : ", a.runDirPath())
	err = os.Remove(a.runDirPath())
	if err != nil {
		log.WithError(err).Error("error removing ", a.runDirPath())
	}
	fmt.Println("removing : ", a.execLinkPath())
	err = os.Remove(a.execLinkPath())
	if err != nil {
		log.WithError(err).Error("error removing ", a.execLinkPath())
	}

	if purge {
		fmt.Println("removing : ", a.configDir())
		err = os.RemoveAll(a.configDir())
		if err != nil {
			log.WithError(err).Error("error removing config dir")
		}
	}
	fmt.Println("removing : ", a.logDir())
	err = os.RemoveAll(a.logDir())
	if err != nil {
		log.WithError(err).Error("error removing log dir")
	}
	fmt.Println("removing : ", a.homeDir())
	err = os.RemoveAll(a.homeDir())
	if err != nil {
		log.WithError(err).Error("error removing home dir")
	}
	fmt.Fprintln(a.consoleWriter(), "SGX Agent Service uninstalled")
	err = a.stop()
	if err != nil {
		log.WithError(err).Error("error stopping service")
	}
}

func removeService() {
	log.Trace("app:removeService() Entering")
	defer log.Trace("app:removeService() Leaving")

	_, _, err := e.RunCommandWithTimeout(constants.ServiceRemoveCmd, 5)
	if err != nil {
		fmt.Println("Could not remove SGX Agent Service")
		fmt.Println("Error : ", err)
	}
}

func validateSetupArgs(cmd string, args []string) error {
	log.Trace("app:validateSetupArgs() Entering")
	defer log.Trace("app:validateSetupArgs() Leaving")

	switch cmd {
	default:
		return errors.New("Unknown command")

	case "download_ca_cert":
		return nil

	case "update_service_config":
		return nil

	case "all":
		if len(args) != 0 {
			return errors.New("app:validateCmdAndEnv() Please setup the arguments with env")
		}
	}
	return nil
}
