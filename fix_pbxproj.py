import sys

path = '/Users/macbookpro2/myapp/ios/Runner.xcodeproj/project.pbxproj'
with open(path, 'r') as f:
    content = f.read()

# All UUIDs belonging to MyTestApp extension
mytestapp_uuids = [
    '22E5B5CF2F77C3DF00BEAEA7',
    '22E5B5D02F77C3DF00BEAEA7',
    '22E5B5D12F77C3DF00BEAEA7',
    '22E5B5D22F77C3DF00BEAEA7',
    '22E5B5D32F77C3DF00BEAEA7',
    '22E5B5D52F77C3DF00BEAEA7',
    '22E5B5D62F77C3DF00BEAEA7',
    '22E5B5D72F77C3DF00BEAEA7',
    '22E5B5DE2F77C3DF00BEAEA7',
    '22E5B5DF2F77C3DF00BEAEA7',
    '22E5B5E02F77C3DF00BEAEA7',
    '22E5B5E12F77C3DF00BEAEA7',
    '22E5B5E22F77C3DF00BEAEA7',
    '22E5B5E32F77C3DF00BEAEA7',
    '22E5B5E42F77C3DF00BEAEA7',
    '22E5B5E62F77C3DF00BEAEA7',
]

lines = content.split('\n')
out = []

i = 0
while i < len(lines):
    line = lines[i]

    # Check if this line starts a block containing a MyTestApp UUID
    is_block_start = any(uuid in line for uuid in mytestapp_uuids) and '= {' in line

    if is_block_start:
        # Skip this entire brace-delimited block
        depth = line.count('{') - line.count('}')
        i += 1
        while i < len(lines) and depth > 0:
            depth += lines[i].count('{') - lines[i].count('}')
            i += 1
        continue

    # Check if this line is a single-line reference to a MyTestApp UUID
    skip_line = any(uuid in line for uuid in mytestapp_uuids)

    if skip_line:
        i += 1
        continue

    out.append(line)
    i += 1

result = '\n'.join(out)

# Save backup
with open(path + '.bak', 'w') as f:
    f.write(content)

with open(path, 'w') as f:
    f.write(result)

print("Done.")
remaining = [l for l in result.split('\n') if 'MyTestApp' in l]
if remaining:
    print("Remaining MyTestApp references:")
    for l in remaining:
        print(repr(l))
else:
    print("No MyTestApp references remain.")
