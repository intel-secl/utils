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

#ifndef _ENCLAVE_H_
#define _ENCLAVE_H_

#include <assert.h>
#include <stdlib.h>
#include <sgx_tcrypto.h>
#include <user_types.h>

#include <mbusafecrt.h> /* memcpy_s */

// Nonce can be maximum of 256 bits
#define NONCE_MAX_BYTES 32

#define AESGCM_256_KEY_SIZE 32
typedef uint8_t aes_gcm_256bit_key_t[AESGCM_256_KEY_SIZE];

#ifndef BN_CHECK_BREAK
#define BN_CHECK_BREAK(x)  if((x == NULL) || (BN_is_zero(x))){break;}
#endif //BN_CHECK_BREAK

#ifndef NULL_BREAK
#define NULL_BREAK(x)   if(!x){break;}
#endif //NULL_BREAK

#ifndef CLEAR_FREE_MEM
#define CLEAR_FREE_MEM(address, size) {             \
  if (address != NULL) {                          \
  if (size > 0) {                             \
  (void)memset_s(address, size, 0, size); \
  }                                           \
    free(address);                              \
  }                                              \
  }
#endif //CLEAR_FREE_MEM

#if defined(__cplusplus)
extern "C" {
#endif


#if defined(__cplusplus)
}
#endif

#endif /* !_ENCLAVE_H_ */
