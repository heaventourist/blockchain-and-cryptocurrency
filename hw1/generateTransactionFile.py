from hashlib import sha256 as H
import nacl.encoding
import nacl.signing
from nacl.public import PrivateKey
import json
import random, copy
import binascii


numTransaction = 100
num_nodes = 40

def generateNodes():
    nodesInfo = dict()
    for i in range(num_nodes):
        sk = nacl.signing.SigningKey.generate()
        pk = sk.verify_key
        nodesInfo[f'node_{i}'] = {
            'sk': sk,
            'pk': pk.encode(encoder=nacl.encoding.HexEncoder).decode(),
        }
    return nodesInfo


nodesInfo = generateNodes()


def generateGenesisTransaction():
    sender = nodesInfo['node_0']
    senderSK = sender['sk']
    senderPK = sender['pk']
    inputs = []
    outputs = [{'value': 1000, 'pubkey': senderPK}]

    signed = senderSK.sign(json.dumps({'input': inputs, 'output': outputs}, sort_keys=True).encode('utf-8'))
    sig = binascii.hexlify(signed.signature).decode()

    number = H(json.dumps({'input': inputs, 'output': outputs, 'sig': sig}, sort_keys=True).encode('utf-8')).hexdigest()
    transaction = {'number': number, 'input': inputs, 'output': outputs, 'sig': sig}
    return transaction


def main():
    fileContent = []
    workingList = []

    genesisTransaction = generateGenesisTransaction()
    with open('genesisTransaction.json', 'w+') as f:
        json.dump(genesisTransaction, f, indent=4)

    workingList.append(genesisTransaction)
    for i in range(numTransaction):
        inputs = list()
        value = 0

        prevPK = random.choice(random.choice(workingList)['output'])['pubkey']
        for j in range(random.randint(1, 5)):
            owned = list(filter(lambda x: any(y['pubkey'] == prevPK for y in x['output']), workingList))
            if len(owned) == 0:
                break
            prevTransaction = random.choice(owned)
            prevOutputs = prevTransaction['output']
            prevNumber = prevTransaction['number']

            prevOutput = random.choice(list(filter(lambda x: x['pubkey'] == prevPK, prevOutputs)))
            inputs.append({'number': prevNumber, 'output': prevOutput})
            value += prevOutput['value']
            prevOutputs = list(filter(lambda x: x != prevOutput, prevOutputs))
            if len(prevOutputs) > 0:
                prevTransaction['output'] = prevOutputs
            else:
                workingList = list(filter(lambda x: x != prevTransaction, workingList))

        outputs = list()
        while value > 0:
            receiver = nodesInfo[random.choice(list(nodesInfo.keys()))]
            receiverPK = receiver['pk']

            tmpValue = random.randint(1, value)
            value -= tmpValue
            outputs.append({'value': tmpValue, 'pubkey': receiverPK})

        senderPK = prevPK
        sender = nodesInfo[list(filter(lambda x: nodesInfo[x]['pk'] == senderPK, list(nodesInfo.keys())))[0]]

        senderSK = sender['sk']
        signed = senderSK.sign(json.dumps({'input': inputs, 'output': outputs}, sort_keys=True).encode('utf-8'))
        sig = binascii.hexlify(signed.signature).decode()

        number = H(json.dumps({'input': inputs, 'output': outputs, 'sig': sig}, sort_keys=True).encode('utf-8')).hexdigest()
        transaction = {'number': number, 'input': inputs, 'output': outputs, 'sig': sig}
        fileContent.append(transaction)
        workingList.append(copy.deepcopy(transaction))

    with open('transaction.json', 'w+') as f:
        json.dump(fileContent, f, indent=4)


if __name__ == '__main__':
    main()
