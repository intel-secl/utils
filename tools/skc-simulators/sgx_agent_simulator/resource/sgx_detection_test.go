/*
 * Copyright (C) 2020 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */

package resource

import (
	"github.com/stretchr/testify/assert"
	"net/http"
	"net/http/httptest"
	"testing"
)

type TestData struct {
	Description string
	Recorder    *httptest.ResponseRecorder
	Assert      *assert.Assertions
	Test        *testing.T
	Token       string
	URL         string
	StatusCode  int
	PostData    []byte
}

func TestGetSgxQuoteWithoutHeader(t *testing.T) {
	input := TestData{
		Recorder:   httptest.NewRecorder(),
		Assert:     assert.New(t),
		Test:       t,
		URL:        "/sgx_agent/v1/host",
		StatusCode: http.StatusNotAcceptable,
	}
	httptest.NewRequest("GET", input.URL, nil)
	input.Assert.Equal(input.StatusCode, input.Recorder.Code)
	input.Test.Log("Test:", input.Description, ", Response:", input.Recorder.Body)
	input.Test.Log("Test:", input.Description, " ended")
}

func TestSgxQuotePushInvalidData(t *testing.T) {
	input := TestData{
		Recorder:   httptest.NewRecorder(),
		Assert:     assert.New(t),
		Test:       t,
		URL:        "/sgx_agent/v1/host",
		StatusCode: http.StatusOK,
	}
	req := httptest.NewRequest("GET", input.URL, nil)
	req.Header.Add("Accept", "application/json")
	req.Header.Add("Content-Type", "application/json")
	input.Assert.Equal(input.StatusCode, input.Recorder.Code)
	input.Test.Log("Test:", input.Description, ", Response:", input.Recorder.Body)
	input.Test.Log("Test:", input.Description, " ended")

}
