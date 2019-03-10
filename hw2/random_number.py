import math
from random import gauss

my_mean = 2
my_variance = 1

random_numbers = []
cnt = 0
while cnt < 10000:
    num = int(gauss(my_mean, math.sqrt(my_variance))*10)
    if num<0 or num >100:
        continue
    random_numbers.append(num)
    cnt+=1

print(random_numbers)