// Grava o som do engine-sim sem tela, com o dinamômetro segurando o rpm.
//   gravar arquivo.mr pasta_saida [passo_rpm] [rpm_min]
// Saída: pasta/lenta.f32, pasta/on_RRRR.f32 (borboleta aberta) e
// pasta/off_RRRR.f32 (borboleta fechada, motor arrastado), float32 mono
// 44100 Hz, SEM o nivelador automático do engine-sim (o loop não "respira"
// e on/off mantêm a diferença de volume). Uma linha por gravação no stdout.
#include "scripting/include/compiler.h"
#include "include/simulator.h"
#include "include/engine.h"
#include "include/units.h"
#include "include/ignition_module.h"
#include "include/exhaust_system.h"
#include "include/impulse_response.h"

#include <climits>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>
#include <unistd.h>

static std::vector<int16_t> lerWav(const std::string &nome) {
    std::vector<int16_t> amostras;
    std::ifstream f(nome, std::ios::binary);
    if (!f) return amostras;
    char id[4];
    uint32_t tam;
    f.read(id, 4); f.read((char *)&tam, 4); f.read(id, 4);  // RIFF .... WAVE
    while (f.read(id, 4) && f.read((char *)&tam, 4)) {
        if (std::strncmp(id, "data", 4) == 0) {
            amostras.resize(tam / 2);
            f.read((char *)amostras.data(), tam);
            break;
        }
        f.seekg(tam + (tam & 1), std::ios::cur);
    }
    return amostras;
}

// Synthesizer::renderAudio(int) sem o nivelador: devolve o sinal cru.
static float renderCru(Synthesizer &s, int k) {
    const float airNoise = s.m_audioParameters.airNoise;
    const float dF_F_mix = s.m_audioParameters.dF_F_mix;
    const float conv = s.m_audioParameters.convolution;
    float signal = 0;
    for (int i = 0; i < s.m_inputChannelCount; ++i) {
        const float f_in = s.m_filters[i].jitterFilter.fast_f(s.m_inputChannels[i].transferBuffer[k]);
        const float f_dc = s.m_filters[i].inputDcFilter.fast_f(f_in);
        const float f = f_in - f_dc;
        const float f_p = s.m_filters[i].derivative.f(f_in);
        const float noise = 2.0 * ((double)rand() / RAND_MAX) - 1.0;
        const float r = s.m_filters->airNoiseLowPass.fast_f(noise);  // igual ao original (filtro 0)
        const float r_mixed = airNoise * r + (1 - airNoise);
        float v_in = f_p * dF_F_mix + f * r_mixed * (1 - dF_F_mix);
        if (std::fpclassify(v_in) == FP_SUBNORMAL) v_in = 0;
        signal += conv * s.m_filters[i].convolution.f(v_in) + (1 - conv) * v_in;
    }
    return s.m_antialiasing.fast_f(signal);
}

static Simulator *sim = nullptr;
static Engine *eng = nullptr;

// um quadro de 1/60 s; se out != null, guarda o áudio do quadro
static void quadro(std::vector<float> *out) {
    sim->startFrame(1 / 60.0);
    while (sim->simulateStep()) {}
    Synthesizer &s = sim->synthesizer();
    const int n = (int)s.m_inputChannels[0].data.size();
    for (int i = 0; i < s.m_inputChannelCount; ++i) {
        s.m_inputChannels[i].data.read(n, s.m_inputChannels[i].transferBuffer);
        s.m_filters[i].airNoiseLowPass.setCutoffFrequency(
            s.m_audioParameters.airNoiseFrequencyCutoff, s.m_audioSampleRate);
        s.m_filters[i].jitterFilter.setJitterScale(s.m_audioParameters.inputSampleNoise);
    }
    s.m_inputSamplesRead = n;
    for (int k = 0; k < n; ++k) {
        const float v = renderCru(s, k);
        if (out) out->push_back(v);
    }
    sim->endFrame();
}

static void rodar(double seg, std::vector<float> *out = nullptr, double *rpm = nullptr) {
    const int q = (int)(seg * 60 + 0.5);
    double soma = 0;
    for (int i = 0; i < q; ++i) {
        quadro(out);
        soma += eng->getRpm();
    }
    if (rpm) *rpm = soma / q;
}

static void salvar(const std::string &nome, const std::vector<float> &a) {
    FILE *f = fopen(nome.c_str(), "wb");
    fwrite(a.data(), sizeof(float), a.size(), f);
    fclose(f);
}

int main(int argc, char **argv) {
    if (argc < 3) {
        printf("uso: gravar arquivo.mr pasta_saida [passo_rpm] [rpm_min]\n");
        return 1;
    }
    char arq[PATH_MAX], pasta[PATH_MAX];
    if (realpath(argv[1], arq) == nullptr || realpath(argv[2], pasta) == nullptr) {
        printf("caminho invalido\n");
        return 1;
    }
    const int passo = argc > 3 ? atoi(argv[3]) : 500;
    const int rpmMin = argc > 4 ? atoi(argv[4]) : 1000;
    if (chdir(ES_DIR) != 0) return 1;

    es_script::Compiler c;
    c.initialize();
    if (!c.compile(arq)) {
        std::ifstream f("error_log.log");
        std::cout << "ERRO DE COMPILACAO\n" << f.rdbuf();
        return 1;
    }
    es_script::Compiler::Output out = c.execute();
    eng = out.engine;
    if (eng == nullptr || out.vehicle == nullptr || out.transmission == nullptr) {
        printf("SEM MOTOR/VEICULO/CAMBIO\n");
        return 1;
    }
    srand(1);
    sim = eng->createSimulator(out.vehicle, out.transmission);
    sim->setSimulationFrequency(eng->getSimulationFrequency());

    // mesmos parâmetros de áudio que o app aplica no loadEngine
    Synthesizer::AudioParameters ap = sim->synthesizer().getAudioParameters();
    ap.inputSampleNoise = (float)eng->getInitialJitter();
    ap.airNoise = (float)eng->getInitialNoise();
    ap.dF_F_mix = (float)eng->getInitialHighFrequencyGain();
    sim->synthesizer().setAudioParameters(ap);
    for (int i = 0; i < eng->getExhaustSystemCount(); ++i) {
        ImpulseResponse *ir = eng->getExhaustSystem(i)->getImpulseResponse();
        std::vector<int16_t> w = lerWav(ir->getFilename());
        if (w.empty()) {
            printf("SEM IMPULSE RESPONSE %s\n", ir->getFilename().c_str());
            return 1;
        }
        sim->synthesizer().initializeImpulseResponse(w.data(), (unsigned)w.size(), ir->getVolume(), i);
    }

    // partida e lenta
    eng->getIgnitionModule()->m_enabled = true;
    eng->setSpeedControl(0.0);
    sim->m_starterMotor.m_enabled = true;
    rodar(1.0);
    sim->m_starterMotor.m_enabled = false;
    rodar(3.0);
    std::vector<float> a;
    double rpm;
    rodar(3.0, &a, &rpm);
    salvar(std::string(pasta) + "/lenta.f32", a);
    printf("lenta 0 %.0f %zu\n", rpm, a.size());
    fflush(stdout);

    const double red = units::toRpm(eng->getRedline());
    sim->m_dyno.m_enabled = true;
    sim->m_dyno.m_hold = true;
    for (int modo = 0; modo < 2; ++modo) {
        const char *nome = modo == 0 ? "on" : "off";
        eng->setSpeedControl(modo == 0 ? 1.0 : 0.0);
        for (int r = rpmMin; r <= (int)(red + 1); r += passo) {
            sim->m_dyno.m_rotationSpeed = units::rpm(r);
            rodar(1.5);
            a.clear();
            rodar(3.0, &a, &rpm);
            char n[64];
            snprintf(n, sizeof(n), "/%s_%04d.f32", nome, r);
            salvar(std::string(pasta) + n, a);
            printf("%s %d %.0f %zu\n", nome, r, rpm, a.size());
            fflush(stdout);
        }
    }
    return 0;
}
