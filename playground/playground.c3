import std::io;

extern fn int sum(int a, int b);

fn void main()
{
    int result = sum(1, 2);
    io::printfn("1 + 2 = %d", result);
}