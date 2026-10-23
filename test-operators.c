// Regression test for the HID reports encode() in sender.c actually produces.
// Expected values: hardware-tested sender-german-test.c, plus the confirmed '-'/'_' fix.
#define main mac2jb_sender_main
#include "sender.c"
#undef main

int main(void) {
    static const struct { unsigned char c; uint8_t key, mods; } cases[] = {
        {'-',56,0}, {'_',56,2},
        {',',54,2}, {';',54,0}, {'.',55,2}, {':',55,0},
        {'#',50,2}, {'\'',50,0},
        {'>',100,0}, {'<',100,2}, {'|',100,64},
        {'=',39,0}, {'&',35,0}, {'*',48,0}, {'+',48,2},
        {'(',37,0}, {')',38,0}, {'$',33,0}, {'!',30,0}, {'"',31,0},
        {'[',37,64}, {']',38,64}, {'@',20,64},
        {'A',4,0}, {'a',4,2}, {'Y',29,0}, {'Z',28,0}, {'0',39,2}, {'1',30,2},
    };
    int failed = 0;
    for (size_t i = 0; i < sizeof(cases)/sizeof(cases[0]); i++) {
        Stroke s = {0, 0};
        int ok = encode(cases[i].c, &s) && s.key == cases[i].key && s.mods == cases[i].mods;
        if (!ok) {
            printf("FAIL '%c': expected key=%u mods=%u, got key=%u mods=%u\n",
                   cases[i].c, cases[i].key, cases[i].mods, s.key, s.mods);
            failed++;
        }
    }
    Stroke tab;
    if (encode('\t', &tab)) { puts("FAIL: tab must be rejected"); failed++; }
    printf("%s (%zu cases)\n", failed ? "FAILED" : "OK", sizeof(cases)/sizeof(cases[0]));
    return failed != 0;
}
