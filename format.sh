#!/usr/bin/env bash

txt1() {
    text="$1"
    printf '%-s%s\n' ' ' "$text"
}

txt2() {
    text="$1"
    printf '%-4s%s\n' ' ' "$text"
}

txt3() {
    text="$1"
    printf '%-8s%s\n' ' ' "$text"
}
