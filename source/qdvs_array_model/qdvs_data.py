DEPTH = 129
WIDTH = 128

with open("qdvs_sample_data.txt", "w") as f:
    for i in range(DEPTH):
        if i == 0:
            # Debug pattern: all 1s
            value = (1 << WIDTH) - 1
        else:
            value = 1 << (i - 1)

        f.write(f"{value:0{WIDTH}b}\n")