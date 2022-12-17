/*
 * Copyright (C) 2020 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package controllers

// QuoteVerifier is an interface implemented by any entity that can verify SGX Quote
type QuoteVerifier interface {
	VerifyQuote([]byte, []byte) (error, QuoteVerifyAttributes)
}
