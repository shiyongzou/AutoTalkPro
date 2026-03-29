import sys

pbx_path = 'macos/Runner.xcodeproj/project.pbxproj'

with open(pbx_path, 'r') as f:
    content = f.read()

if 'Bundle WeChat Service' in content:
    print('Already exists')
    sys.exit(0)

phase_id = 'BWCS00000000000000000001'

# Shell script build phase object
phase_obj = (
    '\t\t' + phase_id + ' /* Bundle WeChat Service */ = {\n'
    '\t\t\tisa = PBXShellScriptBuildPhase;\n'
    '\t\t\tbuildActionMask = 2147483647;\n'
    '\t\t\tfiles = (\n'
    '\t\t\t);\n'
    '\t\t\tinputPaths = (\n'
    '\t\t\t);\n'
    '\t\t\tname = "Bundle WeChat Service";\n'
    '\t\t\toutputPaths = (\n'
    '\t\t\t);\n'
    '\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
    '\t\t\tshellPath = /bin/sh;\n'
    '\t\t\tshellScript = "DEST=\\"${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources/wechat_service\\"\\nSRC=\\"${SRCROOT}/Runner/Resources/wechat_service\\"\\nif [ -d \\"$SRC\\" ]; then\\n  mkdir -p \\"$DEST\\"\\n  rsync -a --delete \\"$SRC/\\" \\"$DEST/\\"\\n  chmod +x \\"$DEST/node\\"\\nfi";\n'
    '\t\t};\n'
)

# Insert before PBXSourcesBuildPhase
marker = '/* Begin PBXSourcesBuildPhase */'
content = content.replace(marker, phase_obj + marker)

# Add to buildPhases array
lines = content.split('\n')
in_phases = False
for i, line in enumerate(lines):
    if 'buildPhases' in line and '(' in line:
        in_phases = True
    if in_phases and ');' in line.strip():
        lines.insert(i, '\t\t\t\t' + phase_id + ' /* Bundle WeChat Service */,')
        in_phases = False
        break

content = '\n'.join(lines)

with open(pbx_path, 'w') as f:
    f.write(content)

print('Build phase added')
