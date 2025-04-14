#include <array>
#include <cassert>
#include <charconv>
#include <fstream>
#include <iostream>
#include <mutex>
#include <ranges>
#include <semaphore>
#include <sstream>
#include <thread>
#include <utility>
#include <vector>

class line_queue
{
public:
    using element_type = std::pair<std::string, std::size_t>;
    line_queue()         = default;
    line_queue(line_queue const& other)
        : buf_{ other.buf_ }
    {
    }
    void push(element_type new_value)
    {
        not_full_.acquire();
        buf_[(widx_ % buf_size)] = new_value;
        widx_++;
        not_empty_.release();
    }

    void pop(element_type& value)
    {
        not_empty_.acquire();
        value = std::move(buf_[ridx_ % buf_size]);
        ridx_++;
        not_full_.release();
    }

private:
    static constexpr auto buf_size = 1UL;
    using semaphore_type           = std::counting_semaphore<buf_size>;
    semaphore_type not_empty_{ 0 };
    semaphore_type not_full_{ buf_size };
    std::size_t ridx_;
    std::size_t widx_;
    std::array<element_type, buf_size> buf_;
};

class safe_file

{
public:
    safe_file(safe_file&& other)
        : f_{ std::move(other.f_) }
    {
    }

    safe_file(std::ofstream f)
        : f_{ std::move(f) }
    {
    }
    auto write(std::string s) -> void
    {
        std::unique_lock l{ lock_ };
        f_ << s;
    }

    auto put(char c) -> void {
        std::unique_lock l{ lock_ };
        f_.put(c);
    }

private:
    std::ofstream f_;
    std::mutex lock_{};
};

auto open_files(std::size_t n) -> std::vector<safe_file>
{
    std::vector<safe_file> files;
    for (auto i : std::views::iota(0UL, n)) {
        std::stringstream ss;
        ss << "output-" << i << ".csv";
        auto output_file = std::ofstream(ss.str(), std::ios_base::out | std::ios_base::trunc);
        if (!output_file) { throw std::runtime_error("couldn't open output file"); }
        files.emplace_back(std::move(output_file));
    }
    return files;
}

auto process_line(line_queue& lb, std::span<safe_file> f) -> void
{
    auto value = line_queue::element_type{};
    for (;;) {
        lb.pop(value);
        auto [line, file_idx] = value;
        if (line.empty()) break;
        f[file_idx].write(line);
        f[file_idx].put('\n');
    }
}

class file_splitter
{
public:
    using worker_type = std::jthread;
    using queue_type  = line_queue;

    file_splitter(std::span<safe_file> files) : queues_{}, threads_{}, file_count_{files.size()} {
        auto cnt = std::thread::hardware_concurrency();
        assert(cnt != 0);
        for (auto _ : std::views::iota(0UL, cnt)) {
            queues_.emplace_back(line_queue{});
        }
        for (auto i : std::views::iota(0UL, cnt)) {
            threads_.emplace_back(process_line, std::ref(queues_[i]), files);
        }
    }

    auto split(std::ifstream& input_file) -> void {
        auto cnt = std::thread::hardware_concurrency();
        auto buf = std::string{};
        auto i   = 0UL;
        auto j   = 0UL;
        while (std::getline(input_file, buf)) {
            queues_[i].push({ std::move(buf), j });
            i = (i + 1) % cnt;
            j = (j + 1) % file_count_;
        }
        // change for stop token
        for (auto i : std::views::iota(0UL, cnt)) {
            queues_[i].push({ "", 0 });
        }
    }

private:
    std::vector<queue_type> queues_{};
    std::vector<worker_type> threads_{};
    std::size_t file_count_;
};

int main(int argc, char* argv[])
{
    try {
        if (argc != 3) {
            std::cerr << "wrong number of arguments" << '\n';
            return 1;
        }
        auto input_file = std::ifstream(argv[1]);
        if (!input_file) {
            std::perror("couldn't open file");
            return 1;
        }
        auto argv_sv        = std::string_view(argv[2]);
        auto n              = std::size_t{};
        auto [ptr, err] = std::from_chars<std::size_t>(argv_sv.begin(), argv_sv.end(), n);
        if (err != std::errc{}) {
            std::cerr << "error: couldn't open input file \"" << argv[1] << "\": " << std::make_error_code(err).message()
                      << '\n';
            return 1;
        }

        auto files = open_files(n);
        auto fs = file_splitter(files);
        fs.split(input_file);
    } catch (std::exception const& e) {
        std::cerr << "error: " << e.what() << '\n';
    }
    return 0;
}
