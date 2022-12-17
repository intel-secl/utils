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

#include <iostream>
#include <fstream>
#include <user_types.h>

#include "Enclave_u.h"
#include "Untrusted.h"

using namespace std;

/* Global EID shared by multiple threads */
sgx_enclave_id_t global_eid = 0;

static ref_rsa_params_t g_rsa_key1;

typedef struct _sgx_errlist_t {
    sgx_status_t err;
    const char *msg;
    const char *sug; /* Suggestion */
} sgx_errlist_t;

/* Error code returned by sgx_create_enclave */
static sgx_errlist_t sgx_errlist[] = {
    {
        SGX_ERROR_UNEXPECTED,
        "Unexpected error occurred.",
        NULL
    },
    {
        SGX_ERROR_INVALID_PARAMETER,
        "Invalid parameter.",
        NULL
    },
    {
        SGX_ERROR_OUT_OF_MEMORY,
        "Out of memory.",
        NULL
    },
    {
        SGX_ERROR_ENCLAVE_LOST,
        "Power transition occurred.",
        "Please refer to the sample \"PowerTransition\" for details."
    },
    {
        SGX_ERROR_INVALID_ENCLAVE,
        "Invalid enclave image.",
        NULL
    },
    {
        SGX_ERROR_INVALID_ENCLAVE_ID,
        "Invalid enclave identification.",
        NULL
    },
    {
        SGX_ERROR_INVALID_SIGNATURE,
        "Invalid enclave signature.",
        NULL
    },
    {
        SGX_ERROR_OUT_OF_EPC,
        "Out of EPC memory.",
        NULL
    },
    {
        SGX_ERROR_NO_DEVICE,
        "Invalid SGX device.",
        "Please make sure SGX module is enabled in the BIOS, and install SGX driver afterwards."
    },
    {
        SGX_ERROR_MEMORY_MAP_CONFLICT,
        "Memory map conflicted.",
        NULL
    },
    {
        SGX_ERROR_INVALID_METADATA,
        "Invalid enclave metadata.",
        NULL
    },
    {
        SGX_ERROR_DEVICE_BUSY,
        "SGX device was busy.",
        NULL
    },
    {
        SGX_ERROR_INVALID_VERSION,
        "Enclave version was invalid.",
        NULL
    },
    {
        SGX_ERROR_INVALID_ATTRIBUTE,
        "Enclave was not authorized.",
        NULL
    },
    {
        SGX_ERROR_ENCLAVE_FILE_ACCESS,
        "Can't open enclave file.",
        NULL
    },
};

/* Check error conditions for loading enclave */
void print_error_message(sgx_status_t ret)
{
    size_t idx = 0;
    size_t ttl = sizeof sgx_errlist/sizeof sgx_errlist[0];

    for (idx = 0; idx < ttl; idx++) {
        if(ret == sgx_errlist[idx].err) {
            if(NULL != sgx_errlist[idx].sug)
                printf("%s\n", sgx_errlist[idx].sug);
            printf("%s\n", sgx_errlist[idx].msg);
            break;
        }
    }
    
    if (idx == ttl)
    	printf("SGX status code is 0x%X. Please refer to the \"Intel SGX SDK Developer Reference\" for more details.\n", ret);
}

/* Initialize the enclave:
 *   Call sgx_create_enclave to initialize an enclave instance
 */
int initialize_enclave(void)
{
    sgx_status_t ret = SGX_ERROR_UNEXPECTED;
    
    /* Call sgx_create_enclave to initialize an enclave instance */
    /* Debug Support: set 2nd parameter to 1 */
    cout << "libenclave/Untrusted(C/C++) : Enclave path : " << ENCLAVE_FILENAME << endl;
    cout << "libenclave/Untrusted(C/C++) : SGX_DEBUG_FLAG : " <<SGX_DEBUG_FLAG << endl;

    cout << "libenclave/Untrusted(C/C++) : Loading enclave..." <<endl;
    ret = sgx_create_enclave(ENCLAVE_FILENAME, SGX_DEBUG_FLAG, NULL, NULL, &global_eid, NULL);

    if (ret != SGX_SUCCESS) {
        print_error_message(ret);
        return -1;
    }

    cout << "libenclave/Untrusted(C/C++) : Enclave loaded." <<endl;

    return 0;
}

int destroy_enclave() {
    cout << "libenclave/Untrusted(C/C++) : Destroying enclave..." <<endl;

    /* Destroy the enclave */
    sgx_destroy_enclave(global_eid);
    
    return 0;
}

/* OCall functions */
void ocall_print_info_string(const char *str)
{
    /* Proxy/Bridge will check the length and null-terminate 
     * the input string to prevent buffer overflow. 
     */
    printf("libenclave/Trusted(C/C++) : %s\n", str);
}

void ocall_print_error_string(const char *str)
{
    /* Proxy/Bridge will check the length and null-terminate 
     * the input string to prevent buffer overflow. 
     */
    printf("libenclave/Trusted(C/C++) : %s\n", str);
}

sgx_status_t retrive_public_key()
{
    sgx_status_t status = SGX_SUCCESS;
    printf("libenclave/Untrusted(C/C++) : Fetching public key...\n");

    status = enclave_pubkey(global_eid, &status, &g_rsa_key1);

    if (status != SGX_SUCCESS) {
        print_error_message(status);
        return status;
    }
    
    return status;
}

int unwrap_secret(uint8_t* wrapped_secret, size_t wrapped_secret_size) {
    printf ("libenclave/Untrusted(C/C++) : Passing Wrapped Secret of Size %lu to trusted.\n", wrapped_secret_size);
    sgx_status_t status = SGX_SUCCESS;

    status = provision_swk_wrapped_secret(global_eid, &status,
                                          (uint8_t *)wrapped_secret,
                                          wrapped_secret_size);

    print_error_message(status);

    if (status != SGX_SUCCESS) {
        print_error_message(status);
        printf ("\n");
        return -1;
    }

    printf ("libenclave/Untrusted(C/C++) : Successfully unwrapped the secret.\n");
    return 0;
}

int unwrap_SWK(uint8_t* wrappedSWK, size_t wrappedSWKsize) {

    sgx_status_t status = SGX_SUCCESS;

    cout << "libenclave/Untrusted(C/C++) : Passing wrapped SWK to enclave...\n";
    sgx_status_t ret = provision_pubkey_wrapped_swk(global_eid, &status,
                                                    wrappedSWK, wrappedSWKsize);

    if (status != SGX_SUCCESS) {
        printf("libenclave/Untrusted(C/C++) : Failed to get unwrapped SWK - status: ");
        print_error_message (status);
        printf("\n");
        return status;
    }

    if (ret != SGX_SUCCESS) {
        printf("libenclave/Untrusted(C/C++) : Failed to get unwrapped SWK - ret: ");
        print_error_message (ret);
        printf("\n");
        return ret;
    }

    return status;
}

uint8_t *get_public_key (int *kSize) 
{
        uint8_t* key_buffer = NULL;
        sgx_status_t status = SGX_SUCCESS;

        status = retrive_public_key();
        if (status != SGX_SUCCESS) {
	     cout << "libenclave/Untrusted(C/C++) :  Error in getting public key" <<endl;
	     return NULL;
        }

        const char* exponent = (const char *)g_rsa_key1.e;
        const char* modulus = (const char *)g_rsa_key1.n;

	// Public key format : <exponent:REF_E_SIZE_IN_BYTES><modulus:REF_N_SIZE_IN_BYTES>
        key_buffer = (uint8_t*)malloc(REF_N_SIZE_IN_BYTES + REF_E_SIZE_IN_BYTES);
	if (key_buffer == NULL) {
	     printf("Couldn't allocate key_buffer\n");
	     return NULL;
	}

	errno_t err;
        err = memcpy_s(key_buffer, REF_E_SIZE_IN_BYTES, exponent, REF_E_SIZE_IN_BYTES);
	if (err != 0) {
	     printf("Couldn't copy exponent into key_buffer\n");
	     return NULL;
	}

        err = memcpy_s(key_buffer+REF_E_SIZE_IN_BYTES, REF_N_SIZE_IN_BYTES, modulus, REF_N_SIZE_IN_BYTES);
	if (err != 0) {
	     printf("Couldn't copy modulus into key_buffer\n");
	     return NULL;
	}

        *kSize = REF_E_SIZE_IN_BYTES + REF_N_SIZE_IN_BYTES;

        return key_buffer;
}



uint8_t* get_sgx_quote(int* qSize, char *nonce) {
        sgx_status_t status = SGX_SUCCESS;
        uint32_t retval = 0;
        quote3_error_t qe3_ret = SGX_QL_SUCCESS;
        uint32_t quote_size = 0;
        uint8_t* p_quote_buffer = NULL;
        uint8_t* key_buffer = NULL;
        sgx_target_info_t qe_target_info;
        sgx_report_t app_report;
        sgx_quote3_t *p_quote;
        sgx_ql_auth_data_t *p_auth_data;
        sgx_ql_ecdsa_sig_data_t *p_sig_data;
        sgx_ql_certification_data_t *p_cert_data;
	errno_t err;

        cout << "libenclave/Untrusted(C/C++) : ECALL : get public key..." << endl;
        status = retrive_public_key();
        if (status != SGX_SUCCESS) {
	     cout << "libenclave/Untrusted(C/C++) :  Error in getting public key" <<endl;
	     return NULL;
        }

        const char* exponent = (const char *)g_rsa_key1.e;
        const char* modulus = (const char *)g_rsa_key1.n;

        key_buffer = (uint8_t*)malloc(REF_N_SIZE_IN_BYTES + REF_E_SIZE_IN_BYTES);
	if (key_buffer == NULL) {
	     printf("libenclave/Untrusted(C/C++) : Couldn't allocate key_buffer\n");
	     return NULL;
	}

        err = memcpy_s(key_buffer, REF_E_SIZE_IN_BYTES, exponent, REF_E_SIZE_IN_BYTES);
	if (err != 0) {
	     printf("libenclave/Untrusted(C/C++) : Couldn't copy exponent into key_buffer\n");
	     return NULL;
	}

        err = memcpy_s(key_buffer+REF_E_SIZE_IN_BYTES, REF_N_SIZE_IN_BYTES, modulus, REF_N_SIZE_IN_BYTES);
	if (err != 0) {
	     printf("libenclave/Untrusted(C/C++) : Couldn't copy modulus into key_buffer\n");
	     return NULL;
	}

        qe3_ret = sgx_qe_set_enclave_load_policy(SGX_QL_PERSISTENT);
        if(SGX_QL_SUCCESS != qe3_ret) {
	     printf("libenclave/Untrusted(C/C++) : Error in set enclave load policy: 0x%04x\n", qe3_ret);
	     return NULL;
        }

        qe3_ret = sgx_ql_set_path(SGX_QL_PCE_PATH, "/usr/lib64/libsgx_pce.signed.so");
        if(SGX_QL_SUCCESS != qe3_ret) {
	     // We try again with default path for debian based distributions
	     qe3_ret = sgx_ql_set_path(SGX_QL_PCE_PATH, "/usr/lib/x86_64-linux-gnu/libsgx_pce.signed.so");
	     if(SGX_QL_SUCCESS != qe3_ret) {
	       printf("libenclave/Untrusted(C/C++) : Error in setting PCE directory: 0x%04x.\n", qe3_ret);
	       return NULL;
	     }
        }
        qe3_ret = sgx_ql_set_path(SGX_QL_QE3_PATH, "/usr/lib64/libsgx_qe3.signed.so");
        if(SGX_QL_SUCCESS != qe3_ret) {
	     qe3_ret = sgx_ql_set_path(SGX_QL_QE3_PATH, "/usr/lib/x86_64-linux-gnu/libsgx_qe3.signed.so");
	     if(SGX_QL_SUCCESS != qe3_ret) {
		  printf("libenclave/Untrusted(C/C++) : Error in setting QE3 directory: 0x%04x.\n", qe3_ret);
		  return NULL;
	     }
	}

        qe3_ret = sgx_ql_set_path(SGX_QL_QPL_PATH, "/usr/lib64/libdcap_quoteprov.so.1");
        if(SGX_QL_SUCCESS != qe3_ret) {
	     qe3_ret = sgx_ql_set_path(SGX_QL_QPL_PATH, "/usr/lib/x86_64-linux-gnu/libdcap_quoteprov.so.1");
	     if(SGX_QL_SUCCESS != qe3_ret) {
		  printf("libenclave/Untrusted(C/C++) : Error in setting QPL directory: 0x%04x.\n", qe3_ret);
		  return NULL;
	     }
        }

        printf("libenclave/Untrusted(C/C++) : Fetching target info...\n");
        qe3_ret = sgx_qe_get_target_info(&qe_target_info);
        if (SGX_QL_SUCCESS != qe3_ret) {
	     printf("Error in sgx_qe_get_target_info. 0x%04x\n", qe3_ret);
	     return NULL;
        }
        printf("libenclave/Untrusted(C/C++) : Fetching SGX quote size..\n");
        qe3_ret = sgx_qe_get_quote_size(&quote_size);
        if (SGX_QL_SUCCESS != qe3_ret) {
	     printf("Error in sgx_qe_get_quote_size. 0x%04x\n", qe3_ret);
	     return NULL;
        }
        printf("libenclave/Untrusted(C/C++) : Quote size is %d bytes.\n", quote_size);

        p_quote_buffer = (uint8_t*)malloc(quote_size);
        if (NULL == p_quote_buffer) {
	     printf("libenclave/Untrusted(C/C++) : Couldn't allocate quote_buffer\n");
	     return NULL;
        }

        printf("libenclave/Untrusted(C/C++) : ECALL - Fetching enclave report...\n");
        status = enclave_create_report(global_eid,
                                       &retval,
                                       &qe_target_info,
                                       nonce,
                                       &app_report);

        if ((SGX_SUCCESS != status) || (0 != retval)) {
	     printf("libenclave/Untrusted(C/C++) : Report creation failed.\n");
	     return NULL;
        }

        // Get the Quote
        printf("libenclave/Untrusted(C/C++) : Fetching quote using SGX Caching Service (SCS)...\n");
        qe3_ret = sgx_qe_get_quote(&app_report,
                                   quote_size,
                                   p_quote_buffer);

        if (SGX_QL_SUCCESS != qe3_ret) {
	     printf( "libenclave/Untrusted(C/C++) : Error in sgx_qe_get_quote. 0x%04x\n", qe3_ret);
	     return NULL;
        }

        p_quote = (_sgx_quote3_t*)(p_quote_buffer);
        p_sig_data = (sgx_ql_ecdsa_sig_data_t *)p_quote->signature_data;
        p_auth_data = (sgx_ql_auth_data_t*)p_sig_data->auth_certification_data;
        p_cert_data = (sgx_ql_certification_data_t *)((uint8_t *)p_auth_data + sizeof(*p_auth_data) + p_auth_data->size);

        uint32_t certSize = p_cert_data->size;
        uint32_t* cert_information = NULL;
        cert_information = (uint32_t*)malloc(certSize);
        if (NULL == cert_information) {
	     printf("libenclave/Untrusted(C/C++) : Couldn't allocate cert_information buffer!\n");
	     return NULL;
        }

        err = memcpy_s(cert_information, certSize, (unsigned char*)( p_cert_data->certification_data), certSize);
	if (err != 0) {
	     printf("libenclave/Untrusted(C/C++) : memcpy of cert_information failed.\n");
	     return NULL;
	}

        qe3_ret = sgx_qe_cleanup_by_policy();
        if(SGX_QL_SUCCESS != qe3_ret) {
	     printf("libenclave/Untrusted(C/C++) : Error in cleanup enclave load policy: 0x%04x\n", qe3_ret);
	     return NULL;
        }

        printf("libenclave/Untrusted(C/C++) : SGX Quote retrived successfully.\n");

        *qSize = quote_size;

        uint8_t* challenge_final = NULL;
        challenge_final = (uint8_t*)malloc(*qSize);
        if (NULL == challenge_final) {
	     printf("libenclave/Untrusted(C/C++) : Couldn't allocate report buffer!\n");
	     return NULL;
        }

        err = memcpy_s(challenge_final, quote_size, p_quote_buffer, quote_size);
	if (err != 0) {
	     printf("libenclave/Untrusted(C/C++) : memcpy of quote buffer failed.\n");
	     return NULL;
	}

        return challenge_final;
}


/* Application entry */
int SGX_CDECL init()
{
    // Initialize the enclave 
    if(initialize_enclave() < 0){
        return -1; 
    }
    cout << "libenclave/Untrusted(C/C++) : Enclave  id : " << global_eid <<endl;

    return 0;
}

