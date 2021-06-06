#include <stdio.h>

int main() {
    int n = 1;
    // little endian if true
    if(*(char *)&n == 1) {
        printf("Little endian\n");
    } else {
        printf("Big endian\n");
    }

    return 0;
}