#!/bin/bash

function gen_lvalue()
{
  local identifier=(${heap[${1}]})
  local raw=(${heap[${identifier[1]}]})
  local offset=${symbol[${heap[${raw[1]}]}]}

  echo 'mov rax, rbp'
  echo "sub rax, ${offset}"
  echo 'push rax'
}

function gen()
{
  local h=(${heap[${1}]})

  if [[ ${h[0]} = 'pair' ]]; then
    gen "${h[1]}"
    gen "${h[2]}"
    echo 'pop rax'
    return 0
  elif [[ ${h[0]} = 'nil' ]]; then
    return 0
  fi

  if [[ ${h[0]} = 'identifier' ]]; then
    local raw=(${heap[${h[1]}]})
    local offset=${symbol[${heap[${raw[1]}]}]}
    echo 'mov rax, rbp'
    echo "sub rax, ${offset}"
    echo 'mov rax, [rax]'
    echo 'push rax'
    return 0
  elif [[ ${h[0]} = 'number' ]]; then
    local raw=(${heap[${h[1]}]})
    echo "push ${heap[${raw[1]}]}"
    return 0
  fi

  if [[ ${h[0]} = 'return' ]]; then
    gen "${h[1]}"
    echo 'pop rax'
    echo 'mov rsp, rbp'
    echo 'pop rbp'
    echo 'ret'
    return 0
  fi

  if [[ ${h[0]} = 'assign' ]]; then
    gen "${h[1]}"
    gen_lvalue "${h[2]}"
    echo 'pop rdi'
    echo 'pop rax'
    echo 'mov [rdi], rax'
    echo 'push rax'
    return 0
  fi

  gen "${h[1]}"
  gen "${h[2]}"

  echo 'pop rdi'
  echo 'pop rax'

  if [[ ${h[0]} = 'add' ]]; then
    echo 'add rax, rdi'
    echo 'push rax'
  elif [[ ${h[0]} = 'sub' ]]; then
    echo 'sub rax, rdi'
    echo 'push rax'
  elif [[ ${h[0]} = 'mul' ]]; then
    echo 'mul rdi'
    echo 'push rax'
  elif [[ ${h[0]} = 'div' ]]; then
    echo 'mov rdx, 0'
    echo 'div rdi'
    echo 'push rax'
  elif [[ ${h[0]} = 'eq' ]]; then
    echo 'cmp rax, rdi'
    echo 'sete al'
    echo 'movzb rax, al'
    echo 'push rax'
  elif [[ ${h[0]} = 'ne' ]]; then
    echo 'cmp rax, rdi'
    echo 'setne al'
    echo 'movzb rax, al'
    echo 'push rax'
  elif [[ ${h[0]} = 'lt' ]]; then
    echo 'cmp rax, rdi'
    echo 'setl al'
    echo 'movzb rax, al'
    echo 'push rax'
  elif [[ ${h[0]} = 'le' ]]; then
    echo 'cmp rax, rdi'
    echo 'setle al'
    echo 'movzb rax, al'
    echo 'push rax'
  elif [[ ${h[0]} = 'gt' ]]; then
    echo 'cmp rdi, rax'
    echo 'setl al'
    echo 'movzb rax, al'
    echo 'push rax'
  elif [[ ${h[0]} = 'ge' ]]; then
    echo 'cmp rdi, rax'
    echo 'setle al'
    echo 'movzb rax, al'
    echo 'push rax'
  fi
}

function codegen()
{
  echo '.intel_syntax noprefix'
  echo '.global main'
  echo 'main:'
  echo 'push rbp'
  echo 'mov rbp, rsp'
  echo "sub rsp, $offset"
  gen "${1}"
  echo 'pop rax'
  echo 'mov rsp, rbp'
  echo 'pop rbp'
  echo 'ret'
}
