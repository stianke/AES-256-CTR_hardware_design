import random
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



def main():
    if len(sys.argv) < 2:
        print("Usage: python tests_gen.py <number of runs> <number_of_blocks_per_run>")
        sys.exit(1)

    NUMBER_OF_RUNS = int(sys.argv[1])
    NUMBER_OF_BLOCKS_PER_RUN = int(sys.argv[2])

    seed = 0
    for run_ID in range(NUMBER_OF_RUNS):
        generate_test_data_set(seed, run_ID, NUMBER_OF_BLOCKS_PER_RUN)
        seed += NUMBER_OF_BLOCKS_PER_RUN + 1000000

    with open(f'generated_test_data/number_of_test_sets.txt', 'w') as num_tests_file:
        num_tests_file.write(f'{NUMBER_OF_RUNS}\n')




if __name__ == "__main__":
    main()
