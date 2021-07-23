/*
 * Copyright (C) 2020 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package main

import (
	"fmt"
	"github.com/intel-secl/sample-sgx-attestation/v5/common"
	"github.com/pkg/errors"
	"os"
)

var errInvalidCmd = errors.New("Invalid input after command")

type App struct {
	HomeDir        string
	ConfigDir      string
	ExecutablePath string
	ExecLinkPath   string
	RunDirPath     string

	Config *common.Configuration
}

func (a *App) Run(args []string) error {
	defer func() {
		if err := recover(); err != nil {
			log.Errorf("Panic occurred: %+v", err)
		}
	}()
	if len(args) < 2 {
		err := errors.New("Invalid usage of Attesting App ")
		a.printUsageWithError(err)
		return err
	}

	cmd := args[1]
	switch cmd {
	default:
		err := errors.New("Invalid command: " + cmd)
		a.printUsageWithError(err)
		return err
	case "help", "-h", "--help":
		a.printUsage()
		return nil
	case "version", "--version", "-v":
		a.printVersion()
		return nil
	case "run":
		if len(args) != 2 {
			return errInvalidCmd
		}
		if a.configuration() == nil {
			fmt.Println("Error loading configuration")
			os.Exit(1)
		} else {
			log.Info("Configuration loaded.")
		}
		return a.startVerifier()
	}
}

func (a *App) configuration() *common.Configuration {
	c, err := common.LoadConfiguration()

	if err == nil {
		a.Config = c
		return a.Config
	}

	log.Error("Configuration file not found.")

	return nil
}
