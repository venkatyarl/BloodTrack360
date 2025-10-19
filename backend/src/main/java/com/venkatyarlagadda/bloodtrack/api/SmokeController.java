package com.venkatyarlagadda.bloodtrack.api;

import com.venkatyarlagadda.bloodtrack.dto.PingResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import reactor.core.publisher.Mono;

/**
 * ==========================================================
 * Class: SmokeController
 * Package: com.venkatyarlagadda.bloodtrack.api
 * ==========================================================
 *
 * Description:
 *  Unversioned "smoke test" endpoints for quick operational checks.
 *  Keeps basic liveness outside versioned API paths.
 *
 * Author: Venkat Yarlagadda
 * Created: October 19, 2025
 * Version: 1.0
 */
@RestController("/smoke")
@Tag(name = "Smoke", description = "Simple, unversioned operational checks")
public class SmokeController {

    @Value("${spring.application.name:BloodTrackBackend}")
    private String serviceName;

    @GetMapping("/ping")
    @Operation(summary = "Lightweight health ping", description = "Returns a minimal status payload.")
    public Mono<PingResponse> ping() {
        return Mono.just(new PingResponse("ok", serviceName));
    }

    @GetMapping("/whoami")
    @Operation(summary = "Service identity", description = "Returns the running service name.")
    public Mono<String> whoami() {
        return Mono.just(serviceName);
    }
}
