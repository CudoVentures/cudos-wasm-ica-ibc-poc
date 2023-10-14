PROJECT="cudos-wasm-ica-ibc-poc"

# chmod +x ./compile_contract.sh
# ./compile_contract.sh

docker build -t "$PROJECT" .
docker run -it "$PROJECT"
