#!/bin/bash

if [ $(id -u) -ne 0 ] ; then
	echo "❌ Run me as root"
	exit 1
fi

helm delete wordpress
kubectl delete pvc data-wordpress-mariadb-0