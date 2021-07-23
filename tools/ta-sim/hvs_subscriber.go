/*
 * Copyright (C) 2020  Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package main

import (
	"crypto/tls"
	"fmt"
	taModel "github.com/intel-secl/intel-secl/v5/pkg/model/ta"
	"github.com/nats-io/nats.go"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"reflect"
	"strings"
	"time"
)

func NewHVSSubscriber(natsHostId string, cfg *AppConfig, taSimController controller) (*hvsSubscriberImpl, error) {

	if natsHostId == "" {
		return nil, errors.New("The configuration does not have a 'nats-host-id'.")
	}

	return &hvsSubscriberImpl{
		cfg:             cfg,
		natsHostID:      natsHostId,
		taSimController: taSimController,
	}, nil

}

type hvsSubscriberImpl struct {
	natsConnection  *nats.EncodedConn
	cfg             *AppConfig
	natsHostID      string
	taSimController controller
}

func (subscriber *hvsSubscriberImpl) Start() error {

	log.Infof("Starting outbound communications with nats-host-id '%s'", subscriber.natsHostID)

	tlsConfig := tls.Config{
		InsecureSkipVerify: true,
	}

	conn, err := nats.Connect(strings.Join(subscriber.cfg.NatsServers, ","),
		nats.Name(subscriber.natsHostID),
		nats.RetryOnFailedConnect(true),
		nats.MaxReconnects(-1),
		nats.ReconnectWait(5*time.Second),
		nats.Timeout(10*time.Second),
		nats.Secure(&tlsConfig),
		nats.UserCredentials(subscriber.cfg.natsTaSimCredentialsPath),
		nats.DisconnectErrHandler(func(_ *nats.Conn, err error) {
			log.Infof("NATS: Client %s disconnected: %v", subscriber.natsHostID, err)
		}),
		nats.ReconnectHandler(func(_ *nats.Conn) {
			log.Infof("NATS: Client %s reconnected", subscriber.natsHostID)
		}),
		nats.ClosedHandler(func(_ *nats.Conn) {
			log.Infof("NATS: Client %s closed", subscriber.natsHostID)
		}),
		nats.ErrorHandler(func(nc *nats.Conn, s *nats.Subscription, err error) {
			if s != nil {
				log.Errorf("ERROR: NATS: Could not process subscription for subject %q: %v", s.Subject, err)
			} else {
				log.Errorf("ERROR: NATS: %v", err)
			}
		}))

	if err != nil {
		return errors.Wrapf(err, "Failed to connect to url %q", subscriber.cfg.Servers)
	}

	subscriber.natsConnection, err = nats.NewEncodedConn(conn, "json")
	if err != nil {
		log.WithError(err).Error("Error while wrapping an existing NATS connection to utilize the encoded connection")
	}

	log.Infof("Successfully connected to %q", subscriber.cfg.NatsServers)

	// subscribe to quote-request messages
	quoteSubject := taModel.CreateSubject(subscriber.natsHostID, taModel.NatsQuoteRequest)
	subscriber.natsConnection.Subscribe(quoteSubject, func(subject string, reply string, quoteRequest *taModel.TpmQuoteRequest) {
		quoteResponse, err := subscriber.taSimController.getQuoteSignedWithNonce(quoteRequest.Nonce, subscriber.taSimController.tpmQuote.IsTagProvisioned, subscriber.taSimController.tpmQuote.AssetTag)
		if err != nil {
			log.WithError(err).Error("Failed to handle quote-request")
		}

		subscriber.natsConnection.Publish(reply, quoteResponse)
	})

	//subscribe to host-info request messages
	hostInfoSubject := taModel.CreateSubject(subscriber.natsHostID, taModel.NatsHostInfoRequest)
	subscriber.natsConnection.Subscribe(hostInfoSubject, func(m *nats.Msg) {
		hostInfo := subscriber.taSimController.hostInfo
		if reflect.DeepEqual(hostInfo, taModel.Manifest{}) {
			log.WithError(err).Error("Failed to handle quote-request")
		}

		hostInfo.HardwareUUID = subscriber.natsHostID
		subscriber.natsConnection.Publish(m.Reply, hostInfo)
	})

	// subscribe to aik request messages
	aikSubject := taModel.CreateSubject(subscriber.natsHostID, taModel.NatsAikRequest)
	subscriber.natsConnection.Subscribe(aikSubject, func(m *nats.Msg) {
		aik := subscriber.taSimController.aikCert.Raw
		if len(aik) == 0 {
			log.WithError(err).Error("Failed to handle aik-request")
		}

		subscriber.natsConnection.Publish(m.Reply, aik)
	})

	// subscribe to binding key request messages
	bkSubject := taModel.CreateSubject(subscriber.natsHostID, taModel.NatsBkRequest)
	subscriber.natsConnection.Subscribe(bkSubject, func(m *nats.Msg) {
		bk := subscriber.taSimController.bindingKeyCert
		if len(bk) == 0 {
			log.WithError(err).Error("Failed to handle get-binding-certificate")
		}

		subscriber.natsConnection.Publish(m.Reply, bk)
	})

	log.Infof("Running Trust-Agent %s...", subscriber.natsHostID)
	for {
		time.Sleep(10 * time.Second)
	}

	return nil
}

func (subscriber *hvsSubscriberImpl) Stop() error {
	return fmt.Errorf("Not Implemented")
}
