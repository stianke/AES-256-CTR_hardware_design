import sys
import checker_gen

if len(sys.argv) < 2:
    print("Usage: python tests_gen.py <number of runs>")
    sys.exit(1)

NUMBER_OF_RUNS = int(sys.argv[1])
NUMBER_OF_VALUES_PER_RUN = 1000
seed = 0
for i in range(NUMBER_OF_RUNS):
    id = f"{i:03}"
    checker_gen.main(seed, id, NUMBER_OF_VALUES_PER_RUN)
    seed += 1000000
