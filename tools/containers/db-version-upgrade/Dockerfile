#  Copyright (C) 2021 Intel Corporation
#  SPDX-License-Identifier: BSD-3-Clause

FROM postgres:14.2

RUN sed -i 's/$/ 11/' /etc/apt/sources.list.d/pgdg.list

RUN apt-get update && apt-get install -y --no-install-recommends \
		postgresql-11 \
	&& rm -rf /var/lib/apt/lists/*

ENV PGBINOLD /usr/lib/postgresql/11/bin
ENV PGBINNEW /usr/lib/postgresql/14/bin

ENV PGDATAOLD /var/lib/postgresql/11/data
ENV PGDATANEW /var/lib/postgresql/14/data

COPY db-version-upgrade/upgrade.sh /upgrade.sh

RUN chmod +x /upgrade.sh /usr/lib/postgresql/14/bin/pg_upgrade

RUN usermod -u 1001 postgres && usermod -u 1001 postgres

USER postgres

ENTRYPOINT ["./upgrade.sh"]
