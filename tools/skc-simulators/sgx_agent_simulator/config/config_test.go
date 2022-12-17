/*
 * Copyright (C) 2020 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package config

import (
	"io/ioutil"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestLoad(t *testing.T) {
	temp, _ := ioutil.TempFile("", "config.yml")
	temp.WriteString("cmsbaseurl: https://<cms.server.com>:8445/cms/v1/\nsgx_agent:\n")
	defer os.Remove(temp.Name())
	c := Load(temp.Name())
	assert.Equal(t, "https://<cms.server.com>:8445/cms/v1/", c.CMSBaseURL)
}

func TestSave(t *testing.T) {
	temp, _ := ioutil.TempFile("", "config.yml")
	defer os.Remove(temp.Name())
	c := Load(temp.Name())
	c.CMSBaseURL = "https://<cms.server.com>:8445/cms/v2/"
	c.Save()
	c2 := Load(temp.Name())
	assert.Equal(t, "https://<cms.server.com>:8445/cms/v2/", c2.CMSBaseURL)
}
