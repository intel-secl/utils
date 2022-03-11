/*
 * Copyright (C) 2022 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package main

import (
	commLog "github.com/intel-secl/intel-secl/v5/pkg/lib/common/log"
	commLogMsg "github.com/intel-secl/intel-secl/v5/pkg/lib/common/log/message"
	commLogInt "github.com/intel-secl/intel-secl/v5/pkg/lib/common/log/setup"
	"github.com/intel-secl/intel-secl/v5/pkg/lib/common/setup"
	"github.com/pkg/errors"
	"github.com/sirupsen/logrus"
	"github.com/spf13/viper"
	"intel/isecl/fda-sim/v5/config"
	"intel/isecl/fda-sim/v5/constants"
	"io"
	"os"
	"strings"
)

var errInvalidCmd = errors.New("Invalid input after command")

type App struct {
	HomeDir        string
	ConfigDir      string
	LogDir         string
	ExecutablePath string
	ExecLinkPath   string
	RunDirPath     string

	Config *config.Configuration

	ConsoleWriter io.Writer
	ErrorWriter   io.Writer
	LogWriter     io.Writer
	SecLogWriter  io.Writer
}

func (app *App) Run(args []string) error {
	defer func() {
		if err := recover(); err != nil {
			defaultLog.Errorf("Panic occurred: %+v", err)
		}
	}()
	if len(args) < 2 {
		err := errors.New("Invalid usage of " + constants.ServiceName)
		app.printUsageWithError(err)
		return err
	}
	cmd := args[1]
	switch cmd {
	default:
		err := errors.New("Invalid command: " + cmd)
		app.printUsageWithError(err)
		return err
	case "help", "-h", "--help":
		app.printUsage()
	case "run":
		if len(args) != 2 {
			return errInvalidCmd
		}
		return app.run()
	case "update-config":
		if len(args) != 3 {
			return errInvalidCmd
		}
		return app.updateConfig(args[2])
	case "uninstall":
		if len(args) != 2 {
			return errInvalidCmd
		}
		return app.uninstall()
	}
	return nil
}

func (app *App) consoleWriter() io.Writer {
	if app.ConsoleWriter != nil {
		return app.ConsoleWriter
	}
	return os.Stdout
}

func (app *App) errorWriter() io.Writer {
	if app.ErrorWriter != nil {
		return app.ErrorWriter
	}
	return os.Stderr
}

func (app *App) secLogWriter() io.Writer {
	if app.SecLogWriter != nil {
		return app.SecLogWriter
	}
	return os.Stdout
}

func (app *App) logWriter() io.Writer {
	if app.LogWriter != nil {
		return app.LogWriter
	}
	return os.Stderr
}

func (app *App) configuration() *config.Configuration {
	if app.Config != nil {
		return app.Config
	}
	viper.AddConfigPath(app.configDir())
	conf, err := config.LoadConfiguration()
	if err == nil {
		app.Config = conf
		return app.Config
	}
	return nil
}

func (app *App) configureLogs(stdOut, logFile bool) error {
	var ioWriterDefault io.Writer
	ioWriterDefault = app.logWriter()
	if stdOut {
		if logFile {
			ioWriterDefault = io.MultiWriter(os.Stdout, app.logWriter())
		} else {
			ioWriterDefault = os.Stdout
		}
	}
	ioWriterSecurity := io.MultiWriter(ioWriterDefault, app.secLogWriter())

	logConfig := app.Config.Log
	lv, err := logrus.ParseLevel(logConfig.Level)
	if err != nil {
		return errors.Wrap(err, "Failed to initiate loggers. Invalid log level: "+logConfig.Level)
	}
	f := commLog.LogFormatter{MaxLength: logConfig.MaxLength}
	commLogInt.SetLogger(commLog.DefaultLoggerName, lv, &f, ioWriterDefault, false)
	commLogInt.SetLogger(commLog.SecurityLoggerName, lv, &f, ioWriterSecurity, false)

	secLog.Info(commLogMsg.LogInit)
	defaultLog.Info(commLogMsg.LogInit)
	return nil
}
func (app *App) updateConfig(ansFile string) error {
	err := setup.ReadAnswerFileToEnv(ansFile)
	if err != nil {
		return errors.Wrap(err, "Failed to read answer file")
	}
	viper.SetEnvKeyReplacer(strings.NewReplacer(".", "_", "-", "_"))
	viper.AutomaticEnv()
	app.Config = defaultConfig()
	err = app.Config.Save(constants.DefaultConfigFilePath)
	if err != nil {
		return errors.Wrap(err, "Failed to save configuration")
	}
	return nil
}
