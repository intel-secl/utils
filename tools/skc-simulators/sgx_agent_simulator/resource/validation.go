/*
 * Copyright (C) 2020 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package resource

import (
	"intel/isecl/sgx_agent/v4/constants"
	"regexp"
)

var regExMap = map[string]*regexp.Regexp{
	constants.EncPPIDKey:  regexp.MustCompile(`^[0-9a-fA-F]{768}$`),
	constants.CPUSvnKey:   regexp.MustCompile(`^[0-9a-fA-F]{32}$`),
	constants.PceSvnKey:   regexp.MustCompile(`^[0-9a-fA-F]{4}$`),
	constants.PceIDKey:    regexp.MustCompile(`^[0-9a-fA-F]{4}$`),
	constants.QeIDKey:     regexp.MustCompile(`^[0-9a-fA-F]{32}$`),
	constants.ManifestKey: regexp.MustCompile(`^[a-fA-F0-9]+$`)}

func validateInputString(key, inString string) bool {
	regEx := regExMap[key]
	if key == "" || !regEx.MatchString(inString) {
		log.WithField(key, inString).Error("Input Validation")
		return false
	}
	return true
}
