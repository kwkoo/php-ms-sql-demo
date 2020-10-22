PROJ=demo
DB_PASSWORD=SqlServer123

.PHONY: install clean create-project install-db populate-db install-php

install: create-project install-db populate-db install-php
	@echo "Install succeeded"

clean:
	-@oc delete -n $(PROJ) all -l app=php
	-@oc delete -n $(PROJ) cm/php
	-@oc delete all -n $(PROJ) -l app=database
	-@oc delete -n $(PROJ) secret/database

create-project:
	-@oc new-project $(PROJ)

install-db:
	@oc create secret generic database -n $(PROJ) --from-literal=SA_PASSWORD=$(DB_PASSWORD)
	@oc create deployment database \
	  -n $(PROJ) \
	  --image mcr.microsoft.com/mssql/server:2019-latest
	@oc set env \
	  deploy/database \
	  ACCEPT_EULA=Y \
	  --from secret/database \
	  -n $(PROJ)
	oc expose deploy/database -n $(PROJ) --port 1433

populate-db:
	@echo "Waiting for database to start..."
	@oc wait \
	  -n $(PROJ) \
	  --timeout=120s \
	  --for=condition=available \
	  deploy/database
	@echo "Pausing to let the database settle down..."
	@sleep 30
	@oc rsh -n $(PROJ) deploy/database mkdir /tmp/db
	@oc cp db_data/import-data.sh $(PROJ)/`oc get po -l app=database -o jsonpath='{.items[0].metadata.name}'`:/tmp/db/
	@oc cp db_data/Products.csv $(PROJ)/`oc get po -l app=database -o jsonpath='{.items[0].metadata.name}'`:/tmp/db/
	@oc cp db_data/setup.sql $(PROJ)/`oc get po -n $(PROJ) -l app=database -o jsonpath='{.items[0].metadata.name}'`:/tmp/db/
	@oc rsh -n $(PROJ) deploy/database chmod 755 /tmp/db/import-data.sh
	@oc rsh -n $(PROJ) deploy/database /tmp/db/import-data.sh

install-php:
	@oc create cm php \
	  -n $(PROJ) \
	  --from-literal DB_SERVER=database \
	  --from-literal DB_USER=sa \
	  --from-literal DB_PASSWORD=$(DB_PASSWORD) \
	  --from-literal DATABASE=DemoData
	@oc new-app \
	  --name php \
	  --binary \
	  --docker-image ghcr.io/kwkoo/s2i-php-ms-sql:7.3
	@oc set env \
	  -n $(PROJ) \
	  --from cm/php \
	  deploy/php
	@/bin/echo -n "Waiting for imagestreamtag to appear..."
	@while [ `oc get -n $(PROJ) istag/s2i-php-ms-sql:7.3 2>/dev/null | wc -l` -lt 1 ]; do \
	  /bin/echo -n "."; \
	  sleep 1; \
	done
	@echo "done"
	@oc start-build \
	  -n $(PROJ) \
	  --from-dir=docroot \
	  --follow \
	  php
	@oc expose svc/php
	@echo "The demo app will be available at http://`oc get -n $(PROJ) route/php -o jsonpath='{.spec.host}'`"
