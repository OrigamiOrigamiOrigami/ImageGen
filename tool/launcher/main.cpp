// Single-file portable launcher: extracts embedded zip, runs imagegen.exe
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <shlobj.h>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <string>
#include <vector>

namespace fs = std::filesystem;

static constexpr char kMagic[8] = {'I', 'M', 'G', 'P', 'A', 'C', 'K', '1'};
static constexpr size_t kFooterSize = 16;

static std::wstring GetExePath() {
  wchar_t buf[MAX_PATH];
  const DWORD n = GetModuleFileNameW(nullptr, buf, MAX_PATH);
  return std::wstring(buf, n);
}

static bool ReadFileBytes(const fs::path& path, std::vector<uint8_t>& out) {
  std::ifstream in(path, std::ios::binary);
  if (!in) return false;
  in.seekg(0, std::ios::end);
  const auto size = in.tellg();
  if (size <= 0) return false;
  out.resize(static_cast<size_t>(size));
  in.seekg(0, std::ios::beg);
  in.read(reinterpret_cast<char*>(out.data()), size);
  return static_cast<bool>(in);
}

static bool ParsePayload(const std::vector<uint8_t>& data,
                         std::vector<uint8_t>& payload) {
  if (data.size() <= kFooterSize) return false;
  const size_t n = data.size();
  if (std::memcmp(data.data() + n - 16, kMagic, 8) != 0) return false;
  uint64_t payloadSize = 0;
  std::memcpy(&payloadSize, data.data() + n - 8, 8);
  if (payloadSize == 0 || payloadSize > n - kFooterSize) return false;
  const size_t start = n - kFooterSize - static_cast<size_t>(payloadSize);
  payload.assign(data.begin() + static_cast<std::ptrdiff_t>(start),
                 data.begin() + static_cast<std::ptrdiff_t>(start + payloadSize));
  return true;
}

static bool WriteBytes(const fs::path& path, const std::vector<uint8_t>& bytes) {
  std::ofstream out(path, std::ios::binary);
  if (!out) return false;
  out.write(reinterpret_cast<const char*>(bytes.data()),
            static_cast<std::streamsize>(bytes.size()));
  return static_cast<bool>(out);
}

static bool RunCommand(const std::wstring& cmd, const fs::path& workDir) {
  STARTUPINFOW si{};
  PROCESS_INFORMATION pi{};
  si.cb = sizeof(si);
  std::vector<wchar_t> buf(cmd.begin(), cmd.end());
  buf.push_back(L'\0');
  if (!CreateProcessW(nullptr, buf.data(), nullptr, nullptr, FALSE,
                      CREATE_NO_WINDOW, nullptr,
                      workDir.empty() ? nullptr : workDir.c_str(), &si, &pi)) {
    return false;
  }
  WaitForSingleObject(pi.hProcess, INFINITE);
  DWORD code = 1;
  GetExitCodeProcess(pi.hProcess, &code);
  CloseHandle(pi.hThread);
  CloseHandle(pi.hProcess);
  return code == 0;
}

static bool ExtractZip(const fs::path& zipPath, const fs::path& dest) {
  fs::create_directories(dest);
  // Windows 10+ 自带 tar，比 PowerShell Expand-Archive 更稳定
  const std::wstring cmd =
      L"tar.exe -xf \"" + zipPath.wstring() + L"\" -C \"" + dest.wstring() + L"\"";
  return RunCommand(cmd, dest);
}

static fs::path CacheDir(uint64_t payloadSize) {
  wchar_t localApp[MAX_PATH];
  SHGetFolderPathW(nullptr, CSIDL_LOCAL_APPDATA, nullptr, 0, localApp);
  return fs::path(localApp) / L"ImageGen" / L"portable" /
         std::to_wstring(payloadSize);
}

static void ShowError(const wchar_t* msg) {
  MessageBoxW(nullptr, msg, L"ImageGen", MB_ICONERROR);
}

int wmain() {
  const auto exePath = GetExePath();
  std::vector<uint8_t> fileData;
  if (!ReadFileBytes(exePath, fileData)) {
    ShowError(L"无法读取程序文件。");
    return 1;
  }

  std::vector<uint8_t> payload;
  if (!ParsePayload(fileData, payload)) {
    ShowError(L"内嵌数据损坏。");
    return 1;
  }

  const fs::path cache = CacheDir(payload.size());
  const fs::path appExe = cache / L"imagegen.exe";

  if (!fs::exists(appExe)) {
    const fs::path zipPath = cache / L"_payload.zip";
    fs::create_directories(cache);
    if (!WriteBytes(zipPath, payload)) {
      ShowError(L"无法写入临时文件。");
      return 1;
    }
    if (!ExtractZip(zipPath, cache)) {
      ShowError(L"解压失败。");
      return 1;
    }
    fs::remove(zipPath);
  }

  if (!fs::exists(appExe)) {
    ShowError(L"未找到 imagegen.exe。");
    return 1;
  }

  STARTUPINFOW si{};
  PROCESS_INFORMATION pi{};
  si.cb = sizeof(si);
  std::wstring cmd = L"\"" + appExe.wstring() + L"\"";
  std::vector<wchar_t> cmdBuf(cmd.begin(), cmd.end());
  cmdBuf.push_back(L'\0');

  if (!CreateProcessW(nullptr, cmdBuf.data(), nullptr, nullptr, FALSE, 0,
                      nullptr, cache.wstring().c_str(), &si, &pi)) {
    ShowError(L"启动失败。");
    return 1;
  }

  // 等待真正的 ImageGen 进程退出（launcher 不做常驻）
  WaitForSingleObject(pi.hProcess, INFINITE);
  DWORD code = 0;
  GetExitCodeProcess(pi.hProcess, &code);
  CloseHandle(pi.hThread);
  CloseHandle(pi.hProcess);
  return static_cast<int>(code);
}
