// Decompila todas as funções que referenciam as strings listadas (ou endereços dados)
// args: <arquivo_saida> <arquivo_lista>   (lista: uma string por linha, ou 0xENDERECO)
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.mem.*;
import ghidra.program.model.symbol.*;
import java.io.*;
import java.nio.file.*;
import java.util.*;

public class DecompRefs extends GhidraScript {
    @Override
    public void run() throws Exception {
        String[] args = getScriptArgs();
        String out = args[0];
        List<String> items = Files.readAllLines(Paths.get(args[1]));
        Memory mem = currentProgram.getMemory();
        FunctionManager fm = currentProgram.getFunctionManager();
        ReferenceManager rm = currentProgram.getReferenceManager();
        LinkedHashMap<Function, List<String>> funcs = new LinkedHashMap<>();
        for (String it : items) {
            it = it.trim();
            if (it.isEmpty()) continue;
            if (it.startsWith("0x")) {
                Address a = toAddr(Long.parseLong(it.substring(2), 16));
                Function f = fm.getFunctionContaining(a);
                if (f == null) { createFunction(a, null); f = fm.getFunctionAt(a); }
                if (f != null) funcs.computeIfAbsent(f, k -> new ArrayList<>()).add(it);
                continue;
            }
            byte[] pat = (it + "\0").getBytes("ASCII");
            Address a = mem.findBytes(currentProgram.getMinAddress(), pat, null, true, monitor);
            while (a != null) {
                for (Reference r : rm.getReferencesTo(a)) {
                    Function f = fm.getFunctionContaining(r.getFromAddress());
                    if (f != null) funcs.computeIfAbsent(f, k -> new ArrayList<>()).add(it);
                }
                a = mem.findBytes(a.add(1), pat, null, true, monitor);
            }
        }
        DecompInterface di = new DecompInterface();
        di.openProgram(currentProgram);
        try (PrintWriter pw = new PrintWriter(new FileWriter(out))) {
            for (Map.Entry<Function, List<String>> e : funcs.entrySet()) {
                Function f = e.getKey();
                pw.println("// ===== " + f.getName() + " @ " + f.getEntryPoint() + "  refs: " + String.join(", ", new LinkedHashSet<>(e.getValue())));
                DecompileResults res = di.decompileFunction(f, 120, monitor);
                if (res.decompileCompleted()) pw.println(res.getDecompiledFunction().getC());
                else pw.println("// falhou: " + res.getErrorMessage());
            }
        }
        println("funcoes: " + funcs.size());
    }
}
