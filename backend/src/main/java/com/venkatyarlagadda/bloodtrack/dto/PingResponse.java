package com.venkatyarlagadda.bloodtrack.dto;

import io.swagger.v3.oas.annotations.media.Schema;

/**
 * ==========================================================
 * Record: PingResponse
 * Package: com.venkatyarlagadda.bloodtrack.dto
 * ==========================================================
 *
 * Description:
 *  Immutable DTO returned by the SmokeController to indicate
 *  basic liveness of the service (status + service name).
 *
 * Author: Venkat Yarlagadda
 * Created: October 19, 2025
 * Version: 1.0
 *
 * Example:
 *  { "status": "ok", "service": "BloodTrackBackend" }
 */
@Schema(description = "Response model for application health ping.")
public record PingResponse(
        @Schema(example = "ok", description = "Indicates the basic health status of the service.")
        String status,

        @Schema(example = "BloodTrackBackend", description = "Identifies the backend service responding to the ping.")
        String service
) { }
