#!/bin/bash

label_count=0

gen_lvalue()
{
  local h=(${heap[${1}]})

  if [[ ${h[0]} = 'variable' ]]; then
    local raw=(${heap[${h[1]}]})
    local s=(${symbol[${func_name},${heap[${raw[1]}]}]})
    local offset=${s[0]}

    echo 'mov rax, rbp'
    echo "sub rax, ${offset}"
    echo 'push rax'
  elif [[ ${h[0]} = 'dereference' ]]; then
    gen "${h[1]}"
  fi
}

gen()
{
  local h=(${heap[${1}]})

  if [[ ${h[0]} = 'pair' ]]; then
    gen "${h[1]}"
    gen "${h[2]}"
    return 0
  elif [[ ${h[0]} = 'nil' ]]; then
    return 0
  fi

  if [[ ${h[0]} = 'variable' ]]; then
    local raw=(${heap[${h[1]}]})
    local s=(${symbol[${func_name},${heap[${raw[1]}]}]})
    local offset=${s[0]}
    echo 'mov rax, rbp'
    echo "sub rax, ${offset}"
    echo 'mov rax, [rax]'
    echo 'push rax'
    return 0
  elif [[ ${h[0]} = 'dereference' ]]; then
    gen "${h[1]}"
    echo 'pop rax'
    echo 'mov rax, [rax]'
    echo 'push rax'
    return 0
  elif [[ ${h[0]} = 'call' ]]; then
    call_walk()
    {
      local arg=(${heap[${2}]})
      if [[ "${arg[0]}" = 'pair' ]]; then
        gen "${arg[1]}"
        call_walk $((${1} + 1)) "${arg[2]}"
        local regs=('rdi' 'rsi' 'rcx' 'rdx' 'r8' 'r9')
        echo "pop ${regs[${1}]}"
      fi
    }
    call_walk 0 "${h[2]}"

    local raw=(${heap[${h[1]}]})
    echo "call ${heap[${raw[1]}]}"
    echo 'push rax'
    return 0
  elif [[ ${h[0]} = 'number' ]]; then
    local raw=(${heap[${h[1]}]})
    echo "push ${heap[${raw[1]}]}"
    return 0
  elif [[ ${h[0]} = 'declare' ]]; then
    return 0
  fi

  if [[ ${h[0]} = 'statement' ]]; then
    gen "${h[1]}"
    echo 'pop rax'
    return 0
  elif [[ ${h[0]} = 'return' ]]; then
    gen "${h[1]}"
    echo 'pop rax'
    echo 'mov rsp, rbp'
    echo 'pop rbp'
    echo 'ret'
    return 0
  elif [[ ${h[0]} = 'if' ]]; then
    local begin=$((++label_count))
    local end=$((++label_count))

    gen "${h[1]}"
    echo 'pop rax'
    echo 'cmp rax, 0'
    echo "je .L${begin}"
    gen "${h[2]}"
    echo "jmp .L${end}"
    echo ".L${begin}:"
    gen "${h[3]}"
    echo ".L${end}:"
    return 0
  elif [[ ${h[0]} = 'while' ]]; then
    local begin=$((++label_count))
    local end=$((++label_count))

    echo ".L${begin}:"
    gen "${h[1]}"
    echo 'pop rax'
    echo 'cmp rax, 0'
    echo "je .L${end}"
    gen "${h[2]}"
    echo "jmp .L${begin}"
    echo ".L${end}:"
    return 0
  elif [[ ${h[0]} = 'for' ]]; then
    local begin=$((++label_count))
    local end=$((++label_count))

    gen "${h[1]}"
    echo 'pop rax'
    echo ".L${begin}:"
    gen "${h[2]}"
    echo 'pop rax'
    echo 'cmp rax, 0'
    echo "je .L${end}"
    gen "${h[4]}"
    gen "${h[3]}"
    echo 'pop rax'
    echo "jmp .L${begin}"
    echo ".L${end}:"
    return 0
  fi

  if [[ ${h[0]} = 'function' ]]; then
    local raw=(${heap[${h[1]}]})
    func_name="${heap[${raw[1]}]}"

    echo "${func_name}:"
    echo 'push rbp'
    echo 'mov rbp, rsp'
    echo "sub rsp, ${offset[${func_name}]}"

    local regs=('rdi' 'rsi' 'rdx' 'rcx' 'r8' 'r9')
    local param=(${heap[${h[2]}]})
    local i=0
    while [[ "${param[0]}" = 'pair' ]]; do
      local d=(${heap[${param[1]}]})
      local raw=(${heap[${d[1]}]})
      local s=(${symbol[${func_name},${heap[${raw[1]}]}]})
      local offset=${s[0]}
      echo 'mov rax, rbp'
      echo "sub rax, ${offset}"
      echo "mov [rax], ${regs[${i}]}"
      param=(${heap[${param[2]}]})
      i=$((++i))
    done

    gen "${h[4]}"
    echo 'pop rax'
    echo 'mov rsp, rbp'
    echo 'pop rbp'
    echo 'ret'
    return 0
  fi

  if [[ ${h[0]} = 'block' ]]; then
    gen "${h[1]}"
    return 0
  fi

  if [[ ${h[0]} = 'addressof' ]]; then
    gen_lvalue "${h[1]}"
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

codegen()
{
  label_count=0
  echo '.intel_syntax noprefix'
  echo '.global main'
  gen "${1}"
}
