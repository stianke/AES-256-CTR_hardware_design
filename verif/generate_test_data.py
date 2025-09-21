import random
import time
import numpy as np
import sys
import binascii
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
import os


def get_args_from_cli():
    if len(sys.argv) < 3:
        print(f"Usage: python script.py <seed> <id>")
        sys.exit(1)

    seed_arg = sys.argv[1]
    id_arg = sys.argv[2]

    try:
        seed = int(seed_arg)
    except ValueError:
        print("Seed must be an integer.")
        sys.exit(1)

    return seed, id_arg

def generate_random_delay(seed, num_delays, m):
    np.random.seed(seed)
    rng_lst = np.random.poisson(m, num_delays)
    for i in range(len(rng_lst)):
        rng_lst[i] = max(0, rng_lst[i]-m)
    return rng_lst

def generate_random_hex(seed=None, k=32):
    random.seed(seed)
    random_hex = ''.join(random.choices('0123456789abcdef', k=k))
    return random_hex

def aes256_encrypt(hex_key, hex_plaintext):
    plaintext = binascii.unhexlify(hex_plaintext)
    key = binascii.unhexlify(hex_key)

    if len(key) != 32:
        raise ValueError("Key must be 32 bytes (256 bits) long for AES-256.")
    if len(plaintext) != 16:
        raise ValueError("Plaintext must be 16 bytes long.")

    # create a cipher object using the key and ECB mode
    cipher = Cipher(algorithms.AES(key), modes.ECB())
    # create an encryptor
    encryptor = cipher.encryptor()
    # perform the encryption and get the encrypted bytes
    return encryptor.update(plaintext) + encryptor.finalize()

def aes256_ctr_encrypt(hex_key, hex_iv, hex_plaintext_list):
    key = binascii.unhexlify(hex_key)
    iv = binascii.unhexlify(hex_iv)

    if len(key) != 32:
        raise ValueError("Key must be 32 bytes (256 bits) long for AES-256.")
    if len(iv) != 16:
        raise ValueError("IV must be 16 bytes (128 bits) long for AES CTR mode.")
    
    # Check validity of the data
    for block in hex_plaintext_list:
        if len(binascii.unhexlify(block)) != 16:
            raise ValueError("Plaintext block must be 16 bytes long.")

    # concatenate all blocks into one plaintext stream
    plaintext = b''.join(binascii.unhexlify(block) for block in hex_plaintext_list)
    
    # create a cipher object using the key and CTR mode
    cipher = Cipher(algorithms.AES(key), modes.CTR(iv))
    # create an encryptor
    encryptor = cipher.encryptor()
    # perform the encryption and get the encrypted bytes
    ciphertext = encryptor.update(plaintext) + encryptor.finalize()

    ciphertext_blocks = [binascii.hexlify(ciphertext[i:i+16]).decode("utf-8") for i in range(0, len(ciphertext), 16)]
    return ciphertext_blocks

def generate_test_data_set(seed, run_ID, num_blocks):
    id_str = f"{run_ID:03}"

    if not os.path.exists('generated_test_data'):
        os.makedirs('generated_test_data')

    with open(f'generated_test_data/t_{id_str}_seed.txt', 'w') as seed_file:
        seed_file.write(f'{seed}\n')
    
    key = generate_random_hex(seed=seed, k=64)
    seed += 1
    with open(f'generated_test_data/t_{id_str}_key.txt', 'w') as key_file:
        key_file.write(key + '\n')
    
    iv = generate_random_hex(seed=seed, k=32)
    seed += 1
    with open(f'generated_test_data/t_{id_str}_iv.txt', 'w') as iv_file:
        iv_file.write(iv + '\n')

    # generate plaintext
    plaintext_gen = []
    for i in range(num_blocks):
        plaintext_gen.append(generate_random_hex(seed=seed))
        seed += 1

    # generate ciphertext
    ciphertext_gen = aes256_ctr_encrypt(key, iv, plaintext_gen)

    with open(f'generated_test_data/t_{id_str}_plaintext.txt', 'w') as pt_file, open(f'generated_test_data/t_{id_str}_ciphertext.txt', 'w') as ct_file:
        for i in range(num_blocks):
            pt_file.write(plaintext_gen[i] + '\n')
            ct_file.write(ciphertext_gen[i] + '\n')


    producer_delays_ticks = generate_random_delay(seed=seed, num_delays=num_blocks, m=20)
    seed += 1
    consumer_delays_ticks = generate_random_delay(seed=seed, num_delays=num_blocks, m=20)
    seed += 1
    with open(f'generated_test_data/t_{id_str}_producer_delay_ticks.txt', 'w') as prod_delay_file, open(f'generated_test_data/t_{id_str}_consumer_delay_ticks.txt', 'w') as cons_delay_file:
        for i in range(num_blocks):
            prod_delay_file.write(f'{producer_delays_ticks[i]}\n')
            cons_delay_file.write(f'{consumer_delays_ticks[i]}\n')

    return seed



def main():
    if len(sys.argv) < 3:
        print("Usage: python tests_gen.py <number of runs> <number_of_blocks_per_run>")
        sys.exit(1)

    NUMBER_OF_RUNS = int(sys.argv[1])
    NUMBER_OF_BLOCKS_PER_RUN = int(sys.argv[2])
    if len(sys.argv) >= 4:
        seed = int(sys.argv[2])
    else:
        seed = int(time.time()*1000) % 100000000

    print(f'Generating {NUMBER_OF_RUNS} test runs with {NUMBER_OF_BLOCKS_PER_RUN} blocks each, using seed {seed}')
    for run_ID in range(NUMBER_OF_RUNS):
        seed = generate_test_data_set(seed, run_ID, NUMBER_OF_BLOCKS_PER_RUN)

    with open(f'generated_test_data/number_of_test_sets.txt', 'w') as num_tests_file:
        num_tests_file.write(f'{NUMBER_OF_RUNS}\n')




if __name__ == "__main__":
    main()
