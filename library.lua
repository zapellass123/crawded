
-- luarmor_key_module.lua (deobfuscated)

-- Modul ini adalah bagian dari sistem perlindungan skrip Luarmor.
-- Fungsinya adalah untuk memverifikasi kunci lisensi dan memuat skrip utama.

-- Mengambil layanan HttpService dari game Roblox.
local HttpService = game:GetService("HttpService")
-- Mendefinisikan fungsi request yang bisa digunakan untuk HTTP.
local request = (syn and syn.request) or request or http_request

-- == Fungsi Pembantu untuk Operasi Bitwise 32-bit ==
-- Fungsi-fungsi ini penting untuk perhitungan internal, terutama dalam hashing.

-- Memastikan nilai tidak melebihi 32-bit (modulo 2^32).
local function clamp32(x) return x % 0x100000000 end
-- Fungsi bitwise XOR (exclusive OR) kustom.
local function bxor(a, b)
    local r, bit = 0, 1
    while a > 0 or b > 0 do
        local aa, bb = a % 2, b % 2
        if aa ~= bb then r = r + bit end
        a = math.floor(a/2); b = math.floor(b/2); bit = bit * 2
    end
    return r
end
-- Fungsi left-shift (geser bit ke kiri).
local function lshift(x, n) return clamp32(x * 2^n) end
-- Fungsi right-shift (geser bit ke kanan).
local function rshift(x, n) return math.floor(x / 2^n) % 0x100000000 end

-- == Fungsi Hashing Kustom 128-bit ==
-- Fungsi ini mengubah string menjadi hash heksadesimal 32 karakter.
-- Digunakan untuk verifikasi data (misalnya, kunci lisensi).
local function hash128(s)
    local p = {0x5ad69b68, 0x03b7222a, 0x2d074df6, 0xcb4fff2d}
    local q = {0x01c3, 0xa408, 0x964d, 0x4320}
    local i, n = 1, #s
    while i <= n do
        local word = 0
        for k=0,3 do
            local idx = i - 1 + k
            if idx < n then
                local b = s:byte(idx+1)
                word = word + b * 2^(8*k)
            end
        end
        word = clamp32(word)
        for x=1,4 do
            local y = bxor(p[x], word)
            y = bxor(y, p[x % 4 + 1])
            y = clamp32(lshift(y,5) + rshift(y,2) + q[x])
            local A = (x - 1) * 5 % 32
            y = bxor(y, rshift(word, A))
            y = clamp32(y + p[(x + 1) % 4 + 1])
            p[x] = clamp32(y)
        end
        i = i + 4
    end
    for x=1,4 do
        local y, d, e = p[x], p[x%4+1], p[(x+2)%4+1]
        y = clamp32(y + d)
        y = bxor(y, e)
        local A = x * 7 % 32
        p[x] = clamp32(lshift(y, A) + rshift(y, 32 - A))
    end
    local out = {}
    for x=1,4 do out[x] = string.format("%08X", p[x]) end
    return table.concat(out)
end

local script_id -- Variabel untuk menyimpan ID skrip

-- Menguraikan data JSON.
local function json(s) return HttpService:JSONDecode(s) end

-- == Fungsi untuk Memverifikasi Kunci (check_key) ==
-- Fungsi ini berkomunikasi dengan server Luarmor untuk memvalidasi kunci.
local function check_key(key)
    local now = os.time()
    key = tostring(key); script_id = tostring(script_id)

    -- Mendapatkan informasi sinkronisasi dari server Luarmor.
    local sync = request({ Method = "GET", Url = "https://sdkapi-public.luarmor.net/sync" })
    sync = json(sync.Body)

    -- Menggunakan node server acak dari daftar.
    local nodes = sync.nodes
    local node = nodes[math.random(1, #nodes)]
    local url = node .. "check_key?key=" .. key .. "&script_id=" .. script_id

    -- Menyesuaikan waktu lokal dengan waktu server.
    local server_time = sync.st
    local delta = server_time - now
    now = now + delta

    -- Membuat header dengan hash verifikasi.
    local headers = {
        ["clienttime"] = tostring(now),
        -- Hash yang dibuat dari kunci, ID skrip, dan waktu saat ini.
        ["catcat128"]  = hash128(key .. "_cfver1.0_" .. script_id .. "_time_" .. now)
    }

    -- Mengirim permintaan ke server.
    local res = request({ Method = "GET", Url = url, Headers = headers })
    return json(res.Body)
end

-- == Fungsi untuk Memaksa Recache (recache) ==
-- Menghapus dan membuat file sementara untuk memperbarui cache lokal.
local function recache()
    script_id = tostring(script_id)
    if not script_id:match("^[a-f0-9]{32}$") then return end
    pcall(writefile, script_id .. "-cache.lua", "recache required")
    wait(0.1)
    pcall(delfile, script_id .. "-cache.lua")
end

-- == Fungsi untuk Memuat Loader Skrip Utama ==
-- Mengunduh dan menjalankan skrip utama dari server Luarmor.
local function load_loader()
    local code = game:HttpGet("https://api.luarmor.net/files/v3/loaders/" .. tostring(script_id) .. ".lua")
    loadstring(code)()
end

-- == Router Properti dengan Metatable ==
-- Ini adalah bagian yang menyamarkan nama-nama fungsi.
-- Skrip mengembalikan sebuah tabel yang fungsinya diakses berdasarkan hash dari nama properti.
return setmetatable({}, {
    -- Fungsi ini dipanggil ketika properti tidak ditemukan di tabel.
    __index = function(_, k)
        -- Menghitung hash dari nama properti yang diakses.
        local h = hash128(k)
        if h == "30F75B193B948B4E965146365A85CBCC" then return check_key end
        if h == "2BCEA36EB24E250BBAB188C73A74DF10" then return recache end
        if h == "75624F56542822D214B1FE25E8798CC6" then return load_loader end
    end,
    -- Fungsi ini dipanggil ketika properti diatur.
    __newindex = function(_, k, v)
        if k == "script_id" then script_id = v end
    end
})