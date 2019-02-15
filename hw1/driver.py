import threading
import queue
import random
from hashlib import sha256 as H
import json
import copy
import time
import binascii
import nacl.encoding
import nacl.signing
from functools import reduce

NUM_NODES = 20
UNVERIFIED_POOL = list()
GLOBAL_QUEUES = dict()


class myThread(threading.Thread):
    def __init__(self, nodeName, genesisBlock):
        threading.Thread.__init__(self)
        self.looping = True
        self.blockChain = list()
        self.blockChain.append(genesisBlock)
        self.nodeName = nodeName
        self.queue = GLOBAL_QUEUES[self.nodeName]
        self.target = '0x07FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'
        self.iterable = iter(UNVERIFIED_POOL)

    def run(self):
        while self.looping:
            self.checkFork()
            try:
                tx = next(self.iterable)
            except StopIteration:
                self.iterable = iter(UNVERIFIED_POOL)
                continue

            if self.verifyTransaction(tx):
                self.proofOfWork(tx)

    def checkFork(self):
        current_threads = threading.enumerate()
        current_threads.remove(threading.main_thread())
        current_threads.sort(key=lambda x: len(x.blockChain))
        tmp_blockchain = copy.deepcopy(current_threads[-1].blockChain)

        if tmp_blockchain != self.blockChain:
            self.putBackToUnverified(self.blockChain, tmp_blockchain)
            self.blockChain = tmp_blockchain

    def generateBlock(self, tx, nonce):
        prev = H(json.dumps(self.blockChain[-1], sort_keys=True).encode('utf-8')).hexdigest()
        tx = copy.deepcopy(tx)
        nonce = H(bytes(nonce)).hexdigest()
        return {
            'tx': tx,
            'prev': prev,
            'nonce': nonce,
            'pow': H(json.dumps({'tx': tx, 'prev': prev, 'nonce': nonce}, sort_keys=True).encode('utf-8')).hexdigest()
        }

    def verifyTransaction(self, tx):
        # Ensure the transaction is not already on the blockChain (included in an existing valid block)
        if any(x['tx']['number'] == tx['number'] for x in self.blockChain):
            return False

        # number hash is correct
        number = H(json.dumps({'input': tx['input'], 'output': tx['output'], 'sig': tx['sig']}, sort_keys=True).encode('utf-8')).hexdigest()
        if tx['number'] != number:
            return False

        # each number in the input exists as a transaction already on the blockchain
        # each output in the input actually exists in the named transaction
        # each output in the input has the same public key, and that key can verify the signature on this transaction
        inputs = tx['input']
        outputs = tx['output']
        senderPK = inputs[0]['output']['pubkey']
        for i in inputs:
            isTxExist = any(x['tx']['number'] == i['number'] and i['output'] in x['tx']['output'] for x in self.blockChain)
            if not isTxExist:
                return False

            if i['output']['pubkey'] != senderPK:
                return False

            # public key is the most recent recipient of that output (i.e. not a double-spend)
            if any(i in x['tx']['input'] for x in self.blockChain):
                return False

        # senderPK can verify the signature on this transaction
        sig = binascii.unhexlify(tx['sig'])
        verify_key = nacl.signing.VerifyKey(senderPK, encoder=nacl.encoding.HexEncoder)
        try:
            verify_key.verify(json.dumps({'input': tx['input'], 'output': tx['output']}, sort_keys=True).encode('utf-8'), sig)
        except nacl.exceptions.BadSignatureError:
            return False

        # the sum of the input and output values are equal
        sumInput = reduce(lambda x, y: x + y['output']['value'], inputs, 0)
        sumOutput = reduce(lambda x, y: x + y['value'], outputs, 0)
        if sumInput != sumOutput:
            return False
        return True

    def broadcast(self, block):
        for node in GLOBAL_QUEUES.keys():
            GLOBAL_QUEUES[node].put_nowait({'block': copy.deepcopy(block)})

    def proofOfWork(self, tx):
        nonce = 0
        while self.queue.empty():
            prev = H(json.dumps(self.blockChain[-1], sort_keys=True).encode('utf-8')).hexdigest()
            hashValue = H(json.dumps({'tx': tx, 'prev': prev, 'nonce': H(bytes(nonce)).hexdigest()}, sort_keys=True).encode('utf-8')).hexdigest()

            if int(hashValue, 16) < int(self.target, 16):
                block = self.generateBlock(tx, nonce)
                self.broadcast(block)
                break
            else:
                nonce += 1

        broadcasted = self.queue.get_nowait()
        block = broadcasted['block']
        self.checkFork()

        if self.verifyBlock(block):
            self.blockChain.append(block)
            for txx in UNVERIFIED_POOL:
                if txx['number'] == block['tx']['number']:
                    UNVERIFIED_POOL.remove(txx)

    def verifyBlock(self, block):
        isValidPow = int(block['pow'], 16) < int(self.target, 16)
        hashValue = H(json.dumps(self.blockChain[-1], sort_keys=True).encode('utf-8')).hexdigest()
        isValidPrev = hashValue == block['prev']
        isValidTransaction = self.verifyTransaction(block['tx'])
        return True if isValidPow and isValidPrev and isValidTransaction else False

    def putBackToUnverified(self, blockchain1, blockchain2):
        for block in blockchain1:
            # The contained transaction in an invalidated block become unverified 
            # and must be re-added to the global unverified pool by the nodes, if not already there
            if not any(x['tx'] == block['tx'] for x in blockchain2) and not any(x == block['tx'] for x in UNVERIFIED_POOL):
                UNVERIFIED_POOL.append(copy.deepcopy(block['tx']))



def generateGenesisBlock():
    with open('genesisTransaction.json', 'r') as f:
        tx = json.load(f)
    return {
        'tx': tx,
        'prev': H('xxx'.encode('utf-8')).hexdigest(),
        'nonce': H(bytes(1)).hexdigest(),
        'pow': H('xxx'.encode('utf-8')).hexdigest()
    }


def main():
    genesisBlock = generateGenesisBlock()

    for i in range(NUM_NODES):
        nodeName = f'node_{i}'
        GLOBAL_QUEUES[nodeName] = queue.Queue()
        thread = myThread(nodeName, genesisBlock)
        thread.start()

    with open('transaction.json', 'r') as f:
        data = json.load(f)

    print('Running ...')
    for tx in data:
        time.sleep(random.random())
        UNVERIFIED_POOL.append(tx)
    print('Waiting for the output ...')
    print('Sleep for 30 seconds ... ')
    print('If you found the outputs are not of the same length, try sleep for longer time,'+
        'Because the more nodes and transactions, the more time it needs to synchronize the outputs!!')
    time.sleep(30)
    current_threads = threading.enumerate()
    current_threads.remove(threading.main_thread())
    for thread in current_threads:
        with open(f'{thread.nodeName}.json', 'w+') as f:
            json.dump(thread.blockChain, f, indent=4)

    for thread in current_threads:
        thread.looping = False

    print('Output accomplished!!')


if __name__ == '__main__':
    main()
