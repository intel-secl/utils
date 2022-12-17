/*
 * Copyright (C) 2020 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package utils

import (
	"github.com/Waterdrips/jwt-go"
	"github.com/pkg/errors"
	"os/exec"
	"strings"
	"time"
)

func ReadAndParseFromCommandLine(input []string) ([]string, error) {
	cmd := exec.Command(input[0], input[1:]...)
	out, err := cmd.CombinedOutput()
	result := strings.Split(string(out), "\n")
	cleanedResult := deleteEmptyFromSlice(result)
	return cleanedResult, err
}

func deleteEmptyFromSlice(s []string) []string {
	r := make([]string, 0)
	for i := range s {
		trimmed := strings.TrimSpace(s[i])
		if strings.HasPrefix(trimmed, "#") {
			continue
		}
		if trimmed != "" {
			r = append(r, trimmed)
		}
	}
	return r
}

// JwtHasExpired checks if the token is about to expire in 7 days or not.
func JwtHasExpired(tokenString string) (bool, error) {
	if tokenString == "" {
		return true, errors.New("Token is empty")
	}

	// We cannot verify the token since we don't have the key.
	// We can only parse it.
	token, _, err := new(jwt.Parser).ParseUnverified(tokenString, jwt.MapClaims{})
	if err != nil {
		return true, errors.Wrap(err, "Unable to parse JWT")
	}

	// Get the standard claims.
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return true, errors.New("Unable to parse JWT standard claims")
	}

	// VerifyExpiresAt returns true if token is not expired
	expired := !claims.VerifyExpiresAt(time.Now().Add(time.Duration(24*7)*time.Hour).Unix(), false)
	return expired, nil
}
