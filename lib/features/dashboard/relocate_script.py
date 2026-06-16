import sys

filepath = 'dashboard.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

start_acoes = -1
end_acoes = -1

for i, line in enumerate(lines):
    if "Ação (Botões)" in line and "NÃO estiver" in line:
        start_acoes = i
        break

if start_acoes != -1:
    for i in range(start_acoes, len(lines)):
        line = lines[i]
        if "Se" in line and "Expandida" in line:
            end_acoes = i - 5
            break

if start_acoes != -1 and end_acoes != -1:
    acoes_lines = lines[start_acoes:end_acoes]
    
    del lines[start_acoes:end_acoes]
    
    insert_target = -1
    for i in range(start_acoes - 1, start_acoes - 15, -1):
        if lines[i].strip() == "],":
            insert_target = i
            break
            
    if insert_target != -1:
        lines = lines[:insert_target] + acoes_lines + lines[insert_target:]
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.writelines(lines)
        print("Fix Applied Successfully!")
    else:
        print("Failed to find insert target")
else:
    print(f"Failed to find block boundaries. start={start_acoes}, end={end_acoes}")
