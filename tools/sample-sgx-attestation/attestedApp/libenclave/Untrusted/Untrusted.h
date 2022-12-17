/*
 * Copyright (C) 2020-2021 Intel Corporation. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 *   * Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *   * Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in
 *     the documentation and/or other materials provided with the
 *     distribution.
 *   * Neither the name of Intel Corporation nor the names of its
 *     contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */


#ifndef _UNTRUSTED_H_
#define _UNTRUSTED_H_

#define __STDC_WANT_LIB_EXT1__ 1

#include <assert.h>
#include <errno.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>


#include <openssl/bn.h>
#include <openssl/evp.h>
#include <openssl/rsa.h>

#include "safe_lib.h"
#include "sgx_dcap_ql_wrapper.h"
#include "sgx_defs.h"
#include "sgx_eid.h"
#include "sgx_error.h"
#include "sgx_pce.h"
#include "sgx_quote_3.h"
#include "sgx_report.h"
#include "sgx_tcrypto.h"
#include "sgx_urts.h"

#include "Enclave_u.h"

#ifndef TRUE
#define TRUE 1
#endif

#ifndef FALSE
#define FALSE 0
#endif

#define ENCLAVE_FILENAME "./enclave.signed.so"

extern sgx_enclave_id_t global_eid;    /* global enclave id */

void print_error_message(sgx_status_t ret);
int initialize_enclave(void);
sgx_status_t retrive_public_key(void);

#if defined(__cplusplus)
extern "C" {
#endif

  int SGX_CDECL init();
  int destroy_enclave();

  uint8_t* get_sgx_quote(int* x, char *nonce);
  uint8_t* get_public_key(int* x);

  int unwrap_SWK(uint8_t* wrappedSWK, size_t wrappedSWKSize);
  int unwrap_secret(uint8_t* wrappedSecret, size_t wrappedSecretSize);

#if defined(__cplusplus)
}
#endif

#endif /* !_UNTRUSTED_H_ */
