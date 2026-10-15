// Pontua funções pelo número de offsets de parâmetros de física que elas leem
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.*;
import ghidra.program.model.scalar.Scalar;
import ghidra.program.model.lang.Register;
import java.io.*;
import java.nio.file.*;
import java.util.*;

public class ScoreFuncs extends GhidraScript {
    public void run() throws Exception {
        String[] args = getScriptArgs();
        Map<Long, List<String>> offs = new HashMap<>();
        for (String l : Files.readAllLines(Paths.get(args[0]))) {
            String[] p = l.trim().split("\\s+");
            if (p.length < 2) continue;
            offs.computeIfAbsent(Long.parseLong(p[0].substring(2), 16), k -> new ArrayList<>()).add(p[1]);
        }
        List<String> res = new ArrayList<>();
        for (Function f : currentProgram.getFunctionManager().getFunctions(true)) {
            Set<Long> hit = new TreeSet<>();
            InstructionIterator it = currentProgram.getListing().getInstructions(f.getBody(), true);
            int n = 0;
            while (it.hasNext()) {
                Instruction ins = it.next(); n++;
                String m = ins.getMnemonicString();
                if (!(m.equals("lwc1") || m.equals("lw") || m.equals("lqc2") || m.equals("lh") || m.equals("lbu") || m.equals("lb"))) continue;
                Object[] o = ins.getOpObjects(1);
                for (Object x : o) if (x instanceof Scalar) {
                    long v = ((Scalar) x).getSignedValue();
                    if (v >= 0x100 && offs.containsKey(v)) hit.add(v);
                }
            }
            if (hit.size() >= 3) {
                StringBuilder sb = new StringBuilder();
                for (Long h : hit) sb.append(String.format("%x:%s ", h, offs.get(h).get(0)));
                res.add(String.format("%04d %s @ %s (%d instr) | %s", hit.size(), f.getName(), f.getEntryPoint(), n, sb));
            }
        }
        Collections.sort(res, Collections.reverseOrder());
        Files.write(Paths.get(args[1]), res);
        println("funcs: " + res.size());
    }
}
