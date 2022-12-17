/*
 * Copyright (C) 2020 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package main

import (
	"fmt"
	"os"

	logger "github.com/sirupsen/logrus"
)

var log = logger.New()

type customFormatter struct {
	logger.TextFormatter
}

func (f *customFormatter) Format(entry *logger.Entry) ([]byte, error) {
	_, e := f.TextFormatter.Format(entry)
	customLog := "AttestingApp(Golang) : " + entry.Message + "\n"
	return []byte(customLog), e
}

func main() {
	app := &App{}

	Formatter := new(customFormatter)
	Formatter.DisableTimestamp = true
	log.SetFormatter(Formatter)

	err := app.Run(os.Args)
	if err != nil {
		fmt.Println("Error:", err.Error())
		os.Exit(1)
	}
}
