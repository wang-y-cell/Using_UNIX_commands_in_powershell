# 命令参考

本文档说明 `windows_use_linux_order.ps1` 加载后可用的命令、参数与示例。

配置与安装方式见 [README.md](README.md)。

---

## 总览

| 命令 | 作用 |
|------|------|
| `ls` | 列出目录内容（横向多列 / 长列表，彩色） |
| `ll` | 等价于 `ls -alh` |
| `find` | 按名称、类型、时间、大小递归查找 |
| `pwd` | 打印当前工作目录 |
| `mkdir` | 创建目录（支持 `-p`） |
| `touch` | 创建空文件或更新时间戳（支持 `-c`） |
| `rm` | 删除文件/目录（支持 `-r` / `-f`） |
| `cp` | 复制文件/目录（支持 `-r` / `-f` / `-v`） |
| `mv` | 移动/重命名（支持 `-f` / `-v`） |

另有自定义 `prompt`：显示 `wangy@windowsPS:<路径> $` 风格提示符。

多数命令支持 Linux 常见的**组合短选项**，例如 `-al`、`-rf`、`-lh`。也可写成分开的开关：`-l -a`。

---

## ls

列出目录内容。默认横向多列；带 `-l` 时为长列表。

### 选项

| 选项 | 说明 |
|------|------|
| `-a` | 显示以 `.` 开头的隐藏项 |
| `-l` | 长列表：修改时间、大小、名称 |
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
```

### 显示说明

- **目录**：蓝色
- **`.exe` / `.bat` / `.ps1`**：绿色
- **压缩包**（`.zip` / `.7z` / `.rar` / `.tar` / `.gz`）：品红
- **其他文件**：近白色
- 长列表中目录、以及没有大小的项显示为 `-`；大小列按当前列表最长内容自动对齐

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

Linux 风格文件查找（常用子集）。默认从当前目录 `.` 递归搜索，输出匹配项的完整路径。

### 语法

```text
find [路径] [-name 模式] [-iname 模式] [-type f|d|l]
     [-mtime N] [-mmin N] [-atime N] [-ctime N] [-size 规格]
```

路径可省略，默认为 `.`。

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

也支持 `-parents`（`-p` 的别名）。

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

也支持 `-no-create`（`-c` 的别名）。

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

## 提示符 (prompt)

加载脚本后，提示符格式为：

```text
wangy@windowsPS:<当前路径> $
```

其中用户名 `wangy` 与主机标签 `windowsPS` 写在脚本的 `prompt` 函数中，可按需修改。

---

## PowerShell 参数写法提示

PowerShell 会把以 `-` 开头的内容解析为参数名。本脚本已为常见组合开关做了声明，因此下列写法通常都可用：

```powershell
ls -al
ls -a -l
rm -rf folder
find . -name "*.log" -type f
```

若某环境仍把短选项吃掉，可尝试：

```powershell
ls --% -al
ls '-al'
```

`--%` 表示其后参数按字面传递给命令。
