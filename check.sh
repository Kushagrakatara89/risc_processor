echo "Checking alu.v"
iverilog -o iitb_risc alu.v

echo "Checking aluCtrl.v"
iverilog -o iitb_risc aluCtrl.v

echo "Checking branchHist.v"
iverilog -o iitb_risc branchHist.v

echo "Checking branchJumpCtrl.v"
iverilog -o iitb_risc branchJumpCtrl.v

echo "Checking ctrlUnit.v"
iverilog -o iitb_risc ctrlUnit.v

echo "Checking dataMem.v"
iverilog -o iitb_risc dataMem.v

echo "Checking frwdingCntrl.v"
iverilog -o iitb_risc frwdingCntrl.v

echo "Checking instrMem.v"
iverilog -o iitb_risc instrMem.v

echo "Checking loadStoreMultiple.v"
iverilog -o iitb_risc loadStoreMultiple.v

echo "Checking mux.v"
iverilog -o iitb_risc mux.v

echo "Checking registerBank.v"
iverilog -o iitb_risc registerBank.v

echo "Checking Stage12_IF2ID.v"
iverilog -o iitb_risc Stage12_IF2ID.v

echo "Checking Stage23_ID2RR.v"
iverilog -o iitb_risc Stage23_ID2RR.v

echo "Checking Stage34_RR2EX.v"
iverilog -o iitb_risc Stage34_RR2EX.v

echo "Checking Stage45_EX2MM.v"
iverilog -o iitb_risc Stage45_EX2MM.v

echo "Checking Stage56_MM2WB.v"
iverilog -o iitb_risc Stage56_MM2WB.v

echo "Running the whole module"
iverilog -o iitb_risc -c fileList.txt