for name in pizza-kafka-bootstrap pizza-kafka-brokers pizza-kafka-0 pizza-kafka-1 pizza-kafka-2 ; do 
	skupper -c cluster1 -n test service create ${name} 9092
	skupper -c cluster1 -n test service bind ${name} service ${name}.kafka.svc.cluster.local --target-port 9092 
done 
