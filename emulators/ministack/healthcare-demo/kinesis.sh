aws --endpoint-url=http://localhost:4566 kinesis create-stream --stream-name patient-events --shard-count 1
aws --endpoint-url=http://localhost:4566 kinesis list-streams
