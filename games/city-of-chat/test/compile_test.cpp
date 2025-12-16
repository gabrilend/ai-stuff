#include <iostream>
#include <string>
#include <vector>
#include <memory>

// Test C++17 features that CoH might use
int main() {
    std::cout << "C++ Compilation Test for City of Heroes Development" << std::endl;
    
    // Test modern C++ features
    auto test_vector = std::vector<std::string>{"hello", "world", "coh"};
    
    // Test structured bindings (C++17)
    for (const auto& item : test_vector) {
        std::cout << "Item: " << item << std::endl;
    }
    
    // Test smart pointers
    auto smart_ptr = std::make_unique<int>(42);
    std::cout << "Smart pointer value: " << *smart_ptr << std::endl;
    
    std::cout << "Compilation test successful!" << std::endl;
    return 0;
}