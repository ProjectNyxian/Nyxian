/*
 Copyright (C) 2025 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#include <llvm/MC/MCAsmInfo.h>
#include <llvm/MC/MCContext.h>
#include <llvm/MC/MCDisassembler/MCDisassembler.h>
#include <llvm/MC/MCInstrInfo.h>
#include <llvm/MC/MCInst.h>
#include <llvm/MC/MCInstPrinter.h>
#include <llvm/MC/MCRegisterInfo.h>
#include <llvm/MC/MCSubtargetInfo.h>
#include <llvm/Support/TargetSelect.h>
#include <llvm/MC/TargetRegistry.h>
#include <llvm/Support/FormattedStream.h>
#include <llvm/Support/MemoryBuffer.h>
#include <llvm/Support/raw_ostream.h>

#include <vector>
#include <string>
#include <memory>
#include <iostream>

#define CodeBufferMax 10000

extern "C" const char *symbol_for_address(void *addr);

using namespace llvm;

std::vector<std::string> disassembleARM64iOS(uint8_t* code,
                                             size_t psize)
{
    std::vector<std::string> result;
    
    if(code == NULL)
    {
        return result;
    }
    
    bool huntForTheReturn = psize == 0;
    
    std::string triple = "arm64-apple-ios";

    std::string error;
    const Target* target = TargetRegistry::lookupTarget(triple, error);
    if (!target)
    {
        std::cerr << "Target lookup failed: " << error << "\n";
        return result;
    }

    std::unique_ptr<MCRegisterInfo> MRI(target->createMCRegInfo(triple));
    MCTargetOptions MCOptions;
    std::unique_ptr<MCAsmInfo> MAI(
        target->createMCAsmInfo(*MRI, triple, MCOptions)
    );

    std::unique_ptr<MCSubtargetInfo> STI(target->createMCSubtargetInfo(triple, "apple-a12", "+pauth"));
    std::unique_ptr<MCInstrInfo> MCII(target->createMCInstrInfo());
    
    llvm::Triple mTriple(triple);
    MCContext Ctx(mTriple, MAI.get(), MRI.get(), STI.get());
    std::unique_ptr<MCDisassembler> DisAsm(target->createMCDisassembler(*STI, Ctx));
    if(!DisAsm)
    {
        std::cerr << "Could not create disassembler\n";
        return result;
    }

    std::unique_ptr<MCInstPrinter> Printer(
        target->createMCInstPrinter(
            Triple(triple),
            MAI->getAssemblerDialect(),
            *MAI, *MCII, *MRI)
    );
    if(!Printer)
    {
        std::cerr << "Could not create instruction printer\n";
        return result;
    }

    uint64_t address = 0;
    
    ArrayRef<uint8_t> memory(code, CodeBufferMax);

    while(address < CodeBufferMax)
    {
        MCInst inst;
        uint64_t size;

        auto status = DisAsm->getInstruction(inst, size, memory.slice(address), address, nulls());
        if(status == MCDisassembler::Fail || size == 0)
        {
            result.push_back("<unrecognized instruction>");
            address += 4;
            continue;
        }

        const MCInstrDesc &desc = MCII->get(inst.getOpcode());
        std::string asmStr;
        std::string finalStr;
        raw_string_ostream os(asmStr);
        raw_string_ostream finalOS(finalStr);
        Printer->printInst(&inst, address, "", *STI, os);
        
        uint64_t currAddr = ((uint64_t)code + address);
        finalOS << llvm::format("0x%llx ", currAddr) << "<" << "+" << llvm::format("%d", address) << ">:" << os.str();
        
        result.push_back(finalStr);
        
        if(huntForTheReturn)
        {
            if(desc.isReturn())
                break;
        }
        else
        {
            if(psize == 0)
            {
                break;
            }
            psize--;
        }

        address += size;
    }

    return result;
}
