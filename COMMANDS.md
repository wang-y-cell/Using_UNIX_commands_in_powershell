# 命令参考

本文档说明加载本项目后可用的命令、参数与示例。

配置与安装方式见 [README.md](README.md)。

---

## 总览

| 命令 | 作用 |
|------|------|
| `ls` | 列出目录内容（横向多列 / 长列表，彩色；管道时输出文件名） |
| `ll` | 等价于 `ls -alh` |
| `find` | 按名称、类型、时间、大小递归查找（支持管道） |
| `grep` | 按正则匹配文本行（支持文件与管道） |
| `cat` | 输出文件内容（支持管道、行号） |
| `head` | 输出文件或管道的前 N 行（默认 10） |
| `tail` | 输出文件或管道的末 N 行（默认 10；支持 `-n +N`） |
| `wc` | 统计行数 / 词数 / 字节数 |
| `tee` | 将管道内容同时写到文件与成功流 |
| `sort` | 对行排序（支持 `-r`/`-n`/`-u`） |
| `uniq` | 去除相邻重复行（支持 `-c`/`-i`/`-d`） |
| `basename` | 取出路径中的文件名（可去后缀） |
| `dirname` | 取出路径中的目录部分 |
| `tree` | 以树形显示目录结构 |
| `du` | 统计目录/文件占用空间 |
| `df` | 显示文件系统磁盘空间 |
| `ln` | 创建符号链接 / 硬链接 |
| `diff` | 比较两个文本文件差异 |
| `which` | 定位命令（可执行文件 / 函数 / 别名） |
| `clear` | 清屏 |
| `pwd` | 打印当前工作目录 |
| `mkdir` | 创建目录（支持 `-p`） |
| `touch` | 创建空文件或更新时间戳（支持 `-c`） |
| `rm` | 删除文件/目录（支持 `-r` / `-f`） |
| `cp` | 复制文件/目录（支持 `-r` / `-f` / `-v`） |
| `mv` | 移动/重命名（支持 `-f` / `-v`） |

另有自定义 `prompt`：显示 `windows@PS:<路径> $` 风格提示符。

多数命令支持 Linux 常见的**组合短选项**，例如 `-al`、`-rf`、`-lh`、`-in`。也可写成分开的开关：`-l -a`。

命令多为**简单函数**，通过 `$args` 解析短选项，因此可直接写 `ls -al`、`rm -rf`、`grep -in`。

### 路径通配符

带路径/文件参数的命令支持展开：

| 语法 | 说明 |
|------|------|
| `*` / `?` / `[abc]` | 单层目录匹配（如 `*.txt`、`file?.log`） |
| `**` | 完整路径段，匹配零或多层目录（如 `src/**/*.ps1`） |

- 通配**无匹配**时静默跳过（该参数不产生结果；若全部被跳过，可能触发原有的 `missing operand`；`ls *.nomatch` 输出为空，不会改列当前目录）
- **不展开为路径**：`which` 的命令名、`find -name`/`-iname` 等模式参数
- `grep` 的 PATTERN：优先作正则；若正则非法且含 `*`/`?`/`[]`，则按通配符匹配整行（如 `ls | grep "*.txt"`）
- 无通配符的字面路径行为与原先一致（不存在仍由各命令报错）

---

## ls

列出目录内容。默认横向多列（Linux 风格：先下后右、按列定宽）；带 `-l` 时为长列表。

接入管道时改为向成功流输出**文件名**（无彩色排版），便于 `ls | grep`。

### 选项

| 选项 | 说明 |
|------|------|
| `-a` | 显示以 `.` 开头的隐藏项 |
| `-l` | 长列表：Mode、修改时间、大小、名称 |
| `-h` | 人类可读大小（`K`/`M`/`G`…）；单独使用时等价于 `-lh` |
| 组合 | `-al`、`-la`、`-lh`、`-alh` 等均可 |

### 示例

```powershell
ls
ls C:\Windows
ls -a
ls -l
ls -lh
ls -al
ls -alh
ls -l -a .\docs
ls .\src\common | grep Color
```

### 显示说明

- **目录**：蓝色
- **`.exe` / `.bat` / `.ps1`**：绿色
- **压缩包**（`.zip` / `.7z` / `.rar` / `.tar` / `.gz`）：红色系
- **图片**（`.jpg` / `.png` / `.gif`）：紫色
- **其他文件**：近白色
- 长列表列顺序为：Windows Mode（如 `d-----` / `-a----`）、修改时间、大小、名称；目录及无大小项显示为 `-`；大小列按当前列表最长内容自动对齐

---

## ll

固定等价于 `ls -alh`（显示隐藏项 + 长列表 + 可读大小）。

### 示例

```powershell
ll
ll .\src
ll C:\Users
```

---

## find

Linux 风格文件查找（常用子集）。默认从当前目录 `.` 递归搜索，向成功流输出匹配项的完整路径（可管道）。

也支持从管道接收搜索根路径。

### 语法

```text
find [路径...] [-name 模式] [-iname 模式] [-type f|d|l]
     [-mtime N] [-mmin N] [-atime N] [-ctime N] [-size 规格]
```

路径可省略，默认为 `.`；也可通过管道传入一个或多个路径。

### 选项

| 选项 | 说明 |
|------|------|
| `-name` | 按文件名匹配（区分大小写，支持通配符 `*`、`?`） |
| `-iname` | 按文件名匹配（不区分大小写） |
| `-type f` | 普通文件 |
| `-type d` | 目录 |
| `-type l` | 符号链接 |
| `-mtime N` | 按修改时间（天）过滤 |
| `-mmin N` | 按修改时间（分钟）过滤 |
| `-atime N` | 按访问时间（天）过滤 |
| `-ctime N` | 按“状态变更”过滤；Windows 上近似为创建时间 |
| `-size` | 按文件大小过滤（目录会跳过） |

### 数值比较约定（与 GNU find 类似）

对 `-mtime` / `-mmin` / `-atime` / `-ctime` / `-size`：

| 写法 | 含义 |
|------|------|
| `+N` | 大于 N |
| `-N` | 小于 N |
| `N` | 等于 N（时间按向下取整的天数/分钟数比较） |

### `-size` 单位

| 后缀 | 含义 |
|------|------|
| 无后缀 | `N × 512` 字节（与 GNU find 默认块一致） |
| `b` / `c` | 字节 |
| `k` / `K` | KiB |
| `m` / `M` | MiB |
| `g` / `G` | GiB |

### 示例

```powershell
find . -name "*.txt"
find . -iname "*.TXT" -type f
find .\src -type d
find . -type f -mtime -1
find . -type f -mmin -30
find . -type f -size +100M
find C:\temp -name "log*" -type f -size -10k
find . -type f -name "*.ps1" | grep Color
'.\src\common' | find -name "Write*"
'.\src', '.\docs' | find -type f -name "*.md"
```

---

## grep

按正则表达式匹配文本行。可从文件读取，也可从管道接收输入。

若 PATTERN 不是合法正则、但又像通配符（含 `*` / `?` / `[]`），则按通配符对**整行**匹配（便于 `ls | grep "*.txt"`）。

### 语法

```text
grep [选项] PATTERN [FILE...]
... | grep [选项] PATTERN
```

### 选项

| 选项 | 说明 |
|------|------|
| `-i` | 忽略大小写 |
| `-v` | 反向匹配（输出不匹配的行） |
| `-n` | 显示行号 |
| 组合 | `-in`、`-iv` 等 |

管道对象若为文件系统对象，按**名称**匹配；字符串则按内容匹配。

### 示例

```powershell
grep error app.log
grep -i error app.log
grep -n TODO app.log notes.txt
ls .\src\common | grep Color
ls | grep "*.txt"
find . -name "*.ps1" | grep grep
Get-Content app.log | grep -v debug
'one','two','txtfile' | grep txt
```

无文件且无管道输入时会报错。

---

## cat

输出文件内容到成功流（可继续管道）。也支持从管道接收行并原样（或带行号）输出。

### 选项

| 选项 | 说明 |
|------|------|
| `-n` | 对全部行编号 |
| `-b` | 仅对非空行编号（优先于 `-n`） |

### 示例

```powershell
cat a.txt
cat -n a.txt b.txt
cat -b a.txt
Get-Content a.txt | cat -n
cat README.md | grep powershell
```

未提供文件且无管道时会报错。不支持用单独的 `-` 表示标准输入（请改用管道）。

---

## head

输出每个文件（或管道）的前 N 行，默认 10 行。多个文件时打印 `==> 文件名 <==` 分隔头。

### 选项

| 选项 | 说明 |
|------|------|
| `-n N` / `-nN` / `-N` | 输出前 N 行 |

### 示例

```powershell
head a.txt
head -n 5 a.txt
head -3 README.md
head a.txt b.txt
Get-Content a.txt | head -n 5
cat README.md | head -n 3
```

---

## tail

输出每个文件（或管道）的末 N 行，默认 10 行。多个文件时打印 `==> 文件名 <==` 分隔头。

### 选项

| 选项 | 说明 |
|------|------|
| `-n N` / `-nN` / `-N` | 输出末 N 行 |
| `-n +N` / `-n+N` | 从第 N 行起输出到末尾 |

### 示例

```powershell
tail a.txt
tail -n 5 a.txt
tail -n +3 a.txt
Get-Content a.txt | tail -n 5
cat README.md | tail -n 2
```

不支持 `-f`（跟随写入）。

---

## wc

统计行数、词数、字节数。未指定选项时三项都输出；多个文件时最后多一行 `total`。

### 选项

| 选项 | 说明 |
|------|------|
| `-l` | 只统计行数 |
| `-w` | 只统计词数 |
| `-c` | 只统计字节数（文件用实际大小；管道按 UTF-8 估算） |
| 组合 | `-lw`、`-lc` 等 |

### 示例

```powershell
wc a.txt
wc -l a.txt b.txt
Get-Content a.txt | wc -l
cat README.md | wc -w
```

---

## tee

从管道读取内容，写入一个或多个文件的同时，原样输出到成功流。

### 选项

| 选项 | 说明 |
|------|------|
| `-a` | 追加写入（默认覆盖） |

### 示例

```powershell
Get-Content a.txt | tee out.txt
ls | tee -a log.txt
cat README.md | tee a.txt b.txt | head -n 3
```

必须通过管道提供输入；会覆盖 PowerShell 自带的 `tee`（`Tee-Object`）别名。

---

## sort

对输入行排序后输出。可从文件或管道读取；多个文件的行会合并后再排序。

### 选项

| 选项 | 说明 |
|------|------|
| `-r` | 逆序 |
| `-n` | 按行首数字排序 |
| `-u` | 去重（排序后相邻相同行只保留一行） |
| 组合 | `-ru`、`-nu` 等 |

### 示例

```powershell
sort a.txt
sort -r a.txt
Get-Content a.txt | sort -n
ls | sort -u
```

会覆盖 PowerShell 自带的 `sort`（`Sort-Object`）别名。

---

## uniq

去除**相邻**重复行（通常先 `sort` 再 `uniq`）。可从文件或管道读取。

### 选项

| 选项 | 说明 |
|------|------|
| `-c` | 在每行前显示重复次数 |
| `-i` | 忽略大小写比较 |
| `-d` | 只输出有重复的行 |
| 组合 | `-ci`、`-cd` 等 |

### 示例

```powershell
sort a.txt | uniq
uniq -c a.txt
Get-Content a.txt | sort | uniq -i
'a','a','b','b','b' | uniq -c
```

---

## basename

取出路径的最后一段（文件名）。传统用法可附带要去掉的后缀；`-a` / `-s` 用于多个路径。

### 语法

```text
basename NAME [SUFFIX]
basename -a NAME...
basename -s SUFFIX NAME...
```

### 示例

```powershell
basename C:\foo\bar.txt
basename C:\foo\bar.txt .txt
basename -a a.txt b.txt
basename -s .ps1 .\src\cat\cat.ps1
```

---

## dirname

取出路径的目录部分；无目录时输出 `.`。

### 示例

```powershell
dirname C:\foo\bar.txt
dirname .\src\cat\cat.ps1
dirname bar.txt
dirname a.txt b.txt
```

---

## pwd

打印当前工作目录。

### 选项

| 选项 | 说明 |
|------|------|
| `-P` | 尽量解析为真实路径（通过 `Get-Item` 取 `FullName`） |

### 示例

```powershell
pwd
pwd -P
```

---

## mkdir

创建目录。

### 选项

| 选项 | 说明 |
|------|------|
| `-p` | 创建中间缺失的父目录；目标已存在时不报错 |

### 示例

```powershell
mkdir docs
mkdir -p a\b\c
mkdir dir1 dir2
```

未加 `-p` 时：

- 父目录不存在会报错
- 目标已存在会报错

---

## touch

创建空文件，或更新已存在文件的访问/修改时间。

### 选项

| 选项 | 说明 |
|------|------|
| `-c` | 不创建新文件；仅当文件已存在时更新时间戳 |

### 示例

```powershell
touch note.txt
touch a.txt b.txt
touch -c missing.txt
```

父目录不存在且需要创建文件时会报错。

---

## rm

删除文件或目录。

### 选项

| 选项 | 说明 |
|------|------|
| `-r` / `-R` | 递归删除目录 |
| `-f` | 强制：路径不存在时不报错；尽量抑制删除错误 |
| 组合 | `-rf`、`-fr` 等 |

### 示例

```powershell
rm file.txt
rm -f missing.txt
rm -r old_dir
rm -rf temp_build
rm -r -f cache logs
```

未加 `-r` 时不能删除目录。

---

## cp

复制文件或目录。

### 选项

| 选项 | 说明 |
|------|------|
| `-r` / `-R` | 递归复制目录 |
| `-f` | 覆盖已存在目标 |
| `-v` | 打印 `'源' -> '目标'` |
| 组合 | `-rf`、`-rv`、`-fv` 等 |

### 示例

```powershell
cp a.txt b.txt
cp a.txt D:\backup\
cp -r src dest
cp -rf src dest_existing
cp -v a.txt b.txt
cp file1.txt file2.txt .\outdir\
```

多个源时，最后一个参数必须是已存在的目录。

---

## mv

移动或重命名文件/目录。

### 选项

| 选项 | 说明 |
|------|------|
| `-f` | 覆盖已存在目标 |
| `-v` | 打印 `'源' -> '目标'` |
| 组合 | `-fv`、`-vf` 等 |

### 示例

```powershell
mv old.txt new.txt
mv a.txt D:\archive\
mv -f a.txt b.txt
mv -v dir1 dir2
mv f1.txt f2.txt .\outdir\
```

多个源时，最后一个参数必须是已存在的目录。

---

## tree

以树形结构显示目录。默认隐藏以 `.` 开头的项；彩色规则与 `ls` 相同。

### 选项

| 选项 | 说明 |
|------|------|
| `-a` | 显示隐藏项 |
| `-d` | 只显示目录 |
| `-L N` / `-LN` | 限制递归深度为 N |

### 示例

```powershell
tree
tree .\src
tree -L 2 .\src
tree -d .\src
tree -a -L 1 .
```

---

## du

估算文件或目录占用的磁盘空间。

### 选项

| 选项 | 说明 |
|------|------|
| `-h` | 人类可读大小（K/M/G…） |
| `-s` | 只输出总计 |
| `-a` | 同时列出文件（默认主要列目录） |
| 组合 | `-sh`、`-ah` 等 |

### 示例

```powershell
du -sh .
du -h .\src
du -a .\src\common
du -sh .\src .\docs
```

---

## df

显示文件系统的磁盘空间使用情况（基于 `Get-PSDrive`）。

### 选项

| 选项 | 说明 |
|------|------|
| `-h` | 人类可读大小 |

### 示例

```powershell
df
df -h
df -h C:\
```

未指定路径时列出所有文件系统驱动器；指定路径时只显示该路径所在盘符。

---

## ln

创建链接。`-s` 为符号链接，否则为硬链接（仅文件）。

### 选项

| 选项 | 说明 |
|------|------|
| `-s` | 创建符号链接 |
| `-f` | 若链接名已存在则先删除再创建 |
| 组合 | `-sf`、`-fs` |

### 示例

```powershell
ln -s .\README.md .\readme-link
ln -sf .\src\load.ps1 .\load-link
ln .\README.md .\readme-hard   # 硬链接（同卷文件）
```

Windows 上创建符号链接通常需要**管理员权限**或开启**开发者模式**。

---

## diff

逐行比较两个文本文件，输出类似传统 Unix `diff` 的差异块。

### 选项

| 选项 | 说明 |
|------|------|
| `-q` | 仅报告是否不同，不打印具体差异 |
| `-i` | 忽略大小写 |
| 组合 | `-qi` |

### 示例

```powershell
diff a.txt b.txt
diff -q a.txt b.txt
diff -i old.txt new.txt
```

不支持目录比较。文件相同则无输出。会覆盖 PowerShell 自带的 `diff`（`Compare-Object`）别名。

---

## which

在 PATH、函数与别名中定位命令。

### 选项

| 选项 | 说明 |
|------|------|
| `-a` | 列出全部匹配（不只第一个） |

### 示例

```powershell
which git
which -a ls
which pwd grep
which sort
```

---

## clear

清屏（调用 `Clear-Host`）。

### 示例

```powershell
clear
```

---

## 提示符 (prompt)

加载脚本后，提示符格式为：

```text
windows@PS:<当前路径> $
```

其中标签 `windows@PS` 写在脚本的 `prompt` 函数中，可按需修改。路径分段使用项目颜色常量显示。

---

## PowerShell 参数与管道提示

多数命令使用简单函数 + `$args` 解析短选项，因此下列写法通常都可用：

```powershell
ls -al
ls -a -l
rm -rf folder
grep -in error app.log
find . -name "*.log" -type f
```

常见管道示例：

```powershell
ls | grep Color
find . -type f -name "*.ps1" | grep grep
cat README.md | grep powershell
'.\src' | find -name "*.ps1"
```

若某环境仍把短选项吃掉，可尝试：

```powershell
ls --% -al
ls '-al'
```

`--%` 表示其后参数按字面传递给命令。
