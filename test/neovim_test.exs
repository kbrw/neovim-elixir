defmodule TestPlugin do
  use NVim.Plugin

  defcommand cmd_n1(arg1,arg2 \\ "toto",bang,eval1,count,eval2,_), bang: true, eval: "xx", count: true, eval: "xx" do
    {arg1,arg2,bang,eval1,count,eval2}
  end

  deffunc fun1(arg1,arg2,eval1,eval2,_), eval: "xx", eval: "xx" do
    {arg1,arg2,eval1,eval2}
  end

  defautocmd auto_cmd1(eval1,eval2,_), pattern: "*.ex", eval: "xx", eval: "xx" do
    {eval1,eval2}
  end
end
defmodule NeovimTest do
  use ExUnit.Case

  test "defcommand param arrangement" do
    assert {:reply,{:ok,{:n1,:n2,1,"toto",34,3}},:state} = 
      TestPlugin.handle_call({:command,"CmdN1",
          [[:n1,:n2],34,1,["toto",3]]},nil,:state)
  end

  test "defcommand default params" do
    assert {:reply,{:ok,{nil,"toto",1,"toto",34,3}},:state} = 
      TestPlugin.handle_call({:command,"CmdN1",[[],34,1,["toto",3]]},nil,:state)
  end

  test "deffunc param arrangement" do
    assert {:reply,{:ok,{:n1,:n2,"toto",3}},:state} = 
      TestPlugin.handle_call({:function,"Fun1",
          [[:n1,:n2],["toto",3]]},nil,:state)
  end

  test "defautocmd param arrangement" do
    assert {:reply,{:ok,{"toto",3}},:state} = 
      TestPlugin.handle_call({:autocmd,{"AutoCmd1","*.ex"},
          [["toto",3]]},nil,:state)
  end
end
