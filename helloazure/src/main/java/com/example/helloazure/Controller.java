package com.example.helloazure;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController

public class Controller {

    @GetMapping("greeting")
    public String greeting() {
        return "Hello azure";
    }
    
}
