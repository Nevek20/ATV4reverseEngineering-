// Para cada função: offsets lidos (lwc1/lw) e escritos (swc1/sw), com registrador base
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.*;
import ghidra.program.model.scalar.Scalar;
import ghidra.program.model.lang.Register;
import java.io.*;
import java.util.*;

public class DumpAccess extends GhidraScript {
    public void run() throws Exception {
        PrintWriter pw = new PrintWriter(new FileWriter(getScriptArgs()[0]));
        for (Function f : currentProgram.getFunctionManager().getFunctions(true)) {
            StringBuilder ld = new StringBuilder(), st = new StringBuilder(), calls = new StringBuilder();
            InstructionIterator it = currentProgram.getListing().getInstructions(f.getBody(), true);
            while (it.hasNext()) {
                Instruction ins = it.next();
                String m = ins.getMnemonicString();
                boolean isL = m.equals("lwc1") || m.equals("lw"), isS = m.equals("swc1") || m.equals("sw");
                if (m.equals("jal")) { calls.append(ins.getOpObjects(0)[0]).append(' '); continue; }
                if (!(isL || isS)) continue;
                Object[] o = ins.getOpObjects(1);
                long v = -1; String r = "?";
                for (Object x : o) { if (x instanceof Scalar) v = ((Scalar) x).getSignedValue(); if (x instanceof Register) r = ((Register) x).getName(); }
                if (v < 0 || r.equals("sp") || r.equals("gp")) continue;
                String t = (m.equals("lwc1") || m.equals("swc1")) ? "f" : "i";
                (isL ? ld : st).append(String.format("%s%x ", t, v));
            }
            pw.println(f.getEntryPoint() + "\t" + f.getName() + "\tL:" + ld + "\tS:" + st + "\tC:" + calls);
        }
        pw.close();
    }
}
