rem java -Xdebug -Xrunjdwp:transport=dt_socket,address=8001,server=y,suspend=n -cp ktk.jar;lib/comm.jar krusader.editor.KrusaderEditor
rem java -cp ktk.jar;lib/comm.jar krusader.editor.KrusaderEditor
java -D65C02="Y" -cp ktk.jar;lib/RXTXcomm.jar krusader.editor.KrusaderEditor
rem pause