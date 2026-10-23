// Dinamômetro sem tela do engine-sim: compila um .mr, mede marcha lenta e
// curva de potência a plena carga (dyno em hold, rpm fixa).
#include "scripting/include/compiler.h"
#include "include/simulator.h"
#include "include/engine.h"
#include "include/units.h"
#include "include/ignition_module.h"

#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <string>
#include <climits>
#include <cstdlib>
#include <unistd.h>

static void rodar(Simulator *sim, double s) {
    const int frames = (int)(s * 60);
    for (int f = 0; f < frames; ++f) {
        sim->startFrame(1 / 60.0);
        while (sim->simulateStep()) {}
        sim->endFrame();
    }
}

int main(int argc, char **argv) {
    if (argc < 2) {
        printf("uso: dyno arquivo.mr [lenta] [passo_rpm]\n");
        return 1;
    }
    // o compilador procura o engine_sim.mr em es/ a partir da pasta atual
    char arq[PATH_MAX];
    if (realpath(argv[1], arq) == nullptr) {
        printf("nao achei %s\n", argv[1]);
        return 1;
    }
    if (chdir(ES_DIR) != 0) return 1;

    es_script::Compiler c;
    c.initialize();
    if (!c.compile(arq)) {
        std::ifstream f("error_log.log");
        std::cout << "ERRO DE COMPILACAO\n" << f.rdbuf();
        return 1;
    }
    es_script::Compiler::Output out = c.execute();
    Engine *e = out.engine;
    if (e == nullptr || out.vehicle == nullptr || out.transmission == nullptr) {
        std::ifstream f("error_log.log");
        std::cout << "SEM MOTOR/VEICULO/CAMBIO\n" << f.rdbuf();
        return 1;
    }
    e->calculateDisplacement();
    Simulator *sim = e->createSimulator(out.vehicle, out.transmission);
    sim->setSimulationFrequency(e->getSimulationFrequency());

    const bool soLenta = argc > 2 && std::string(argv[2]) == "lenta";
    e->getIgnitionModule()->m_enabled = true;
    e->setSpeedControl(0.0);
    sim->m_starterMotor.m_enabled = true;
    rodar(sim, 1.0);
    sim->m_starterMotor.m_enabled = false;
    rodar(sim, 4.0);
    double soma = 0, mn = 1e9, mx = 0; int n = 0;
    for (int k = 0; k < 120; ++k) {
        rodar(sim, 1 / 60.0);
        const double r = e->getRpm();
        soma += r; n++; if (r < mn) mn = r; if (r > mx) mx = r;
    }
    printf("lenta %.0f rpm (min %.0f max %.0f)  cilindrada %.0f cc\n",
        soma / n, mn, mx, units::convert(e->getDisplacement(), units::cc));
    if (soLenta) return 0;

    const double red = units::toRpm(e->getRedline());
    sim->m_dyno.m_enabled = true;
    sim->m_dyno.m_hold = true;
    e->setSpeedControl(1.0);
    double picoHp = 0, rpmHp = 0, picoT = 0, rpmT = 0;
    const int passo = argc > 3 ? atoi(argv[3]) : 500;
    for (int rpm = 1500; rpm <= (int)(red + 1); rpm += passo) {
        sim->m_dyno.m_rotationSpeed = units::rpm(rpm);
        rodar(sim, 1.2);
        double t = 0; int m = 0;
        for (int k = 0; k < 30; ++k) { rodar(sim, 1 / 60.0); t += sim->getFilteredDynoTorque(); m++; }
        t /= m;
        const double tNm = units::convert(t, units::Nm);
        const double hp = units::convert(t * units::rpm(rpm), units::hp);
        printf("  %5d rpm  %6.1f N.m  %6.1f hp\n", rpm, tNm, hp);
        if (hp > picoHp) { picoHp = hp; rpmHp = rpm; }
        if (tNm > picoT) { picoT = tNm; rpmT = rpm; }
    }
    printf("pico %.0f hp @ %.0f rpm, %.0f N.m @ %.0f rpm\n", picoHp, rpmHp, picoT, rpmT);
    return 0;
}
