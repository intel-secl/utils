/*
 * Copyright (C) 2022 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package main

import (
	"fmt"
	"os"
	"os/user"
	"strconv"

	"github.com/intel-secl/intel-secl/v5/pkg/lib/common/utils"
)

const (
	ServiceUserName = "fda-sim"
	ServiceDir      = "fda-sim/"
	LogDir          = "/var/log/" + ServiceDir
	LogFile         = LogDir + ServiceUserName + ".log"
	SecurityLogFile = LogDir + ServiceUserName + "-security.log"
)

func openLogFiles() (logFile *os.File, secLogFile *os.File, err error) {

	logFile, err = os.OpenFile(LogFile, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0640)
	if err != nil {
		return nil, nil, err
	}
	err = os.Chmod(LogFile, 0640)
	if err != nil {
		return nil, nil, err
	}

	secLogFile, err = os.OpenFile(SecurityLogFile, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0640)
	if err != nil {
		return nil, nil, err
	}
	err = os.Chmod(SecurityLogFile, 0640)
	if err != nil {
		return nil, nil, err
	}

	// Containers are always run as non root users, does not require changing ownership of log directories
	if utils.IsContainerEnv() {
		return
	}

	fdaUser, err := user.Lookup(ServiceUserName)
	if err != nil {
		return nil, nil, fmt.Errorf("could not find user '%s'", ServiceUserName)
	}

	uid, err := strconv.Atoi(fdaUser.Uid)
	if err != nil {
		return nil, nil, fmt.Errorf("could not parse fda-sim user id '%s'", fdaUser.Uid)
	}

	gid, err := strconv.Atoi(fdaUser.Gid)
	if err != nil {
		return nil, nil, fmt.Errorf("could not parse fda-sim group id '%s'", fdaUser.Gid)
	}

	err = os.Chown(SecurityLogFile, uid, gid)
	if err != nil {
		return nil, nil, fmt.Errorf("could not change file ownership for file: '%s'", SecurityLogFile)
	}
	err = os.Chown(LogFile, uid, gid)
	if err != nil {
		return nil, nil, fmt.Errorf("could not change file ownership for file: '%s'", LogFile)
	}
	return
}

func main() {
	logFile, secLogFile, err := openLogFiles()
	var app *App
	if err != nil {
		app = &App{
			LogWriter: os.Stdout,
		}
	} else {
		defer func() {
			closeLogFiles(logFile, secLogFile)
		}()
		app = &App{
			LogWriter:    logFile,
			SecLogWriter: secLogFile,
		}
	}

	err = app.Run(os.Args)
	if err != nil {
		fmt.Println("Application returned with error : ", err.Error())
		closeLogFiles(logFile, secLogFile)
		os.Exit(1)
	}
}

func closeLogFiles(logFile, secLogFile *os.File) {
	var err error
	err = logFile.Close()
	if err != nil {
		fmt.Println("Failed to close default log file:", err.Error())
	}
	err = secLogFile.Close()
	if err != nil {
		fmt.Println("Failed to close security log file:", err.Error())
	}
}
