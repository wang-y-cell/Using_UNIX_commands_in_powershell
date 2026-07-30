# ll：固定等价于 ls -alh（简单函数，直接把 -alh 与路径传入 $args）
function ll {
    $all = @('-alh') + @($args)
    ls-horizontal @all
}
