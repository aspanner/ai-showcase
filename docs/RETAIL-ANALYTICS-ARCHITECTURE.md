# Smart Retail Analytics - Architecture Diagram

## System Architecture

```mermaid
graph TB
    subgraph "User Interface Layer"
        UI[Web Browser UI]
        VideoDisplay[Video Display Container]
        OverlayCanvas[Overlay Canvas<br/>Detection Boxes & Paths]
        HeatmapCanvas[Heatmap Canvas<br/>Traffic Visualization]
        Controls[Control Panel<br/>Start/Stop/Upload]
        Config[Configuration Panel<br/>VLM Endpoint & Settings]
        Stats[Stats Panel<br/>Metrics & Analytics]
    end

    subgraph "Input Sources"
        Camera[Live Camera<br/>getUserMedia API]
        UploadVideo[Uploaded Video File<br/>File Input]
        DemoVideo[Demo Video<br/>/assets/retail.mp4]
    end

    subgraph "Core Processing Engine"
        VideoElement[HTML5 Video Element<br/>Rendering at 16:9]
        AnalysisLoop[Analysis Loop<br/>Interval: 2-10s configurable]
        FrameCapture[Frame Capture<br/>Canvas.toDataURL<br/>JPEG 0.8 quality]
        RenderLoop[Render Loop<br/>requestAnimationFrame<br/>~60 FPS]
    end

    subgraph "AI/ML Layer - RHAIIS"
        VLM_API[VLM API Endpoint<br/>RHAIIS vLLM Server<br/>Port 8000]
        VLM_Model[Qwen2-VL-2B-Instruct<br/>Vision Language Model]
        VLM_Response[JSON Response<br/>people_count, positions, activity]
    end

    subgraph "Data Processing Layer"
        ResponseParser[VLM Response Parser<br/>JSON extraction & validation]
        CoordMapper[Coordinate Mapper<br/>Percentage to Canvas Pixels]
        DetectionStore[Detection Store<br/>Array of detected people]
        PathTracker[Movement Path Tracker<br/>Track last 30 positions per person]
        HeatmapData[Heatmap Data Grid<br/>2D intensity array]
    end

    subgraph "Rendering Layer"
        HeatmapRenderer[Heatmap Renderer<br/>Radial gradients + blur]
        DetectionRenderer[Detection Box Renderer<br/>Boxes, labels, timestamps]
        PathRenderer[Movement Path Renderer<br/>Lines, arrows, dots]
        StatsCalculator[Stats Calculator<br/>Visitor counts, zone analysis]
    end

    subgraph "Data Storage"
        State[Application State<br/>isRunning, visitorCount, etc]
        MovementPaths[Movement Paths Object<br/>personId → positions array]
        HeatmapGrid[Heatmap Grid Data<br/>gridHeight × gridWidth array]
    end

    %% User interactions
    UI --> Controls
    UI --> Config
    Controls --> Camera
    Controls --> UploadVideo
    Controls --> DemoVideo

    %% Video source setup
    Camera --> VideoElement
    UploadVideo --> VideoElement
    DemoVideo --> VideoElement
    VideoElement --> VideoDisplay

    %% Analysis flow
    VideoElement --> AnalysisLoop
    AnalysisLoop --> FrameCapture
    FrameCapture --> VLM_API
    
    %% VLM processing
    VLM_API --> VLM_Model
    VLM_Model --> VLM_Response
    VLM_Response --> ResponseParser

    %% Data processing
    ResponseParser --> CoordMapper
    CoordMapper --> DetectionStore
    DetectionStore --> PathTracker
    DetectionStore --> HeatmapData
    
    PathTracker --> MovementPaths
    HeatmapData --> HeatmapGrid

    %% Rendering flow
    RenderLoop --> HeatmapRenderer
    RenderLoop --> DetectionRenderer
    RenderLoop --> PathRenderer
    RenderLoop --> StatsCalculator

    HeatmapGrid --> HeatmapRenderer
    DetectionStore --> DetectionRenderer
    MovementPaths --> PathRenderer
    HeatmapGrid --> StatsCalculator

    HeatmapRenderer --> HeatmapCanvas
    DetectionRenderer --> OverlayCanvas
    PathRenderer --> OverlayCanvas
    StatsCalculator --> Stats

    %% State management
    State -.-> AnalysisLoop
    State -.-> RenderLoop
    DetectionStore -.-> State
    HeatmapGrid -.-> State

    %% Display
    HeatmapCanvas --> UI
    OverlayCanvas --> UI
    VideoDisplay --> UI
    Stats --> UI

    style VLM_API fill:#dc2626,color:#fff
    style VLM_Model fill:#dc2626,color:#fff
    style HeatmapCanvas fill:#f59e0b,color:#000
    style OverlayCanvas fill:#10b981,color:#fff
    style VideoElement fill:#3b82f6,color:#fff
```

## Data Flow Sequence

```mermaid
sequenceDiagram
    participant User
    participant UI
    participant Video as Video Element
    participant Analysis as Analysis Loop
    participant VLM as RHAIIS VLM API
    participant Parser as Response Parser
    participant Heatmap as Heatmap Engine
    participant Render as Render Loop
    participant Canvas as Canvas Display

    User->>UI: Start Camera / Upload Video
    UI->>Video: Initialize video source
    Video->>UI: Video ready (onloadedmetadata)
    UI->>Analysis: Start analysis interval (2-10s)
    UI->>Render: Start render loop (60 FPS)
    
    loop Every 2-10 seconds
        Analysis->>Video: Capture current frame
        Video->>Analysis: Frame image data (JPEG)
        Analysis->>VLM: POST /v1/chat/completions
        Note over VLM: Qwen2-VL analyzes image<br/>Returns people positions
        VLM-->>Analysis: JSON response
        Analysis->>Parser: Parse VLM response
        Parser->>Parser: Extract JSON from response
        Parser->>Parser: Map coordinates (% to pixels)
        Parser->>Heatmap: Add detection points
        Parser->>Heatmap: Update movement paths
        Heatmap->>Heatmap: Update intensity grid
    end
    
    loop Every frame (~60 FPS)
        Render->>Heatmap: Get heatmap data
        Render->>Canvas: Render heatmap (radial gradients)
        Render->>Canvas: Draw detection boxes
        Render->>Canvas: Draw movement paths
        Render->>UI: Update stats display
        Canvas-->>User: Visual feedback
    end
    
    User->>UI: Stop analysis
    UI->>Analysis: Clear interval
    UI->>Render: Stop render loop
    Render->>Canvas: Final heatmap render
```

## Component Details

### 1. **Video Input Processing**
- Supports 3 input modes: live camera, uploaded video, demo video
- Video rendered at 16:9 aspect ratio
- Camera resolution: 1280x720 (ideal)
- Frame capture uses canvas to extract JPEG at 0.8 quality

### 2. **VLM Integration (RHAIIS)**
- **Endpoint**: `https://rhaiis-route-rhaiis.apps.sno.sandbox73.opentlc.com`
- **Model**: Qwen2-VL-2B-Instruct (Vision Language Model)
- **API**: OpenAI-compatible chat completions endpoint
- **Timeout**: 120 seconds (2 minutes)
- **Request**: Includes text prompt + base64 JPEG image
- **Response**: JSON with people_count, positions (x%, y%), and activity

### 3. **Detection Processing**
- Parses VLM JSON response (handles truncated responses)
- Converts percentage positions (0-100%) to canvas pixels
- Auto-detects normalized (0-1) vs percentage (0-100) formats
- Tracks each person with unique ID
- Stores timestamp for age calculation

### 4. **Movement Tracking**
- Maintains path history per person ID
- Stores last 30 positions per person
- Each position includes: x, y, timestamp
- Paths rendered with colored lines and arrows
- Fade effect based on position age (10 second fade)

### 5. **Heatmap Rendering**
- Grid-based intensity accumulation (10px grid cells)
- Radial gradient rendering for smooth appearance
- 5-color gradient: Blue → Cyan → Green → Yellow → Red
- Blur filter (20px) for professional look
- Configurable radius (20-100px)

### 6. **Detection Overlay**
- Bounding boxes around detected people
- Fresh detections (<3s): Red with "LIVE" badge
- Old detections (>3s): Gray with age timestamp
- Shows: Person ID, coordinates, activity, age
- Pulsing animation on fresh detections

### 7. **Statistics & Analytics**
- **Current Visitors**: Active people count
- **Total Visitors**: Peak occupancy (max seen at once)
- **Avg Dwell Time**: Simulated (20-50s)
- **Zone Analysis**: Hot/Warm/Cool/Cold percentages
- **Activity Log**: Timestamped event history

## Technology Stack

```mermaid
graph LR
    subgraph "Frontend"
        HTML5[HTML5<br/>Video, Canvas]
        CSS3[CSS3<br/>Modern styling]
        JS[Vanilla JavaScript<br/>ES6+]
    end
    
    subgraph "APIs"
        MediaAPI[getUserMedia API<br/>Camera access]
        CanvasAPI[Canvas 2D API<br/>Rendering]
        FetchAPI[Fetch API<br/>HTTP requests]
        RAF[requestAnimationFrame<br/>Render loop]
    end
    
    subgraph "Backend - RHAIIS"
        RHAIIS[Red Hat AI Inference Server]
        vLLM[vLLM Backend<br/>OpenAI-compatible]
        Qwen[Qwen2-VL-2B-Instruct<br/>Vision Model]
    end
    
    HTML5 --> MediaAPI
    HTML5 --> CanvasAPI
    JS --> FetchAPI
    JS --> RAF
    FetchAPI --> RHAIIS
    RHAIIS --> vLLM
    vLLM --> Qwen
```

## Key Features

1. **Real-time Analysis**: VLM processes frames every 2-10 seconds (configurable)
2. **Smooth Visualization**: 60 FPS render loop for fluid animations
3. **Movement Tracking**: Color-coded paths showing customer journey
4. **Heat Mapping**: Accumulated traffic intensity with smooth gradients
5. **Age Indicators**: Shows freshness of detections (LIVE vs X seconds ago)
6. **Responsive Design**: Adapts to window resize with canvas reinitialization
7. **Demo Mode**: Pre-loaded retail video for instant demonstration
8. **Progress Tracking**: Visual feedback for video/camera analysis
9. **Error Handling**: Graceful fallbacks for parsing/connection errors
10. **Security**: HTML escaping for XSS prevention in VLM responses

## Performance Considerations

- **Canvas DPI Scaling**: Handles high-DPI displays (retina, 4K)
- **Offscreen Rendering**: Uses offscreen canvas for heatmap composition
- **Blur Optimization**: Filter applied during final compositing
- **Grid Optimization**: 10px grid cells for efficient data structure
- **Path Limiting**: Max 30 positions per person to prevent memory bloat
- **Activity Log Limiting**: Max 10 log entries displayed

## Configuration Options

- **Analysis Interval**: 1-10 seconds between VLM API calls
- **Heatmap Radius**: 20-100px for heat point spread
- **Show Detection Boxes**: Toggle bounding boxes on/off
- **Show Movement Paths**: Toggle path visualization on/off
- **Toggle Overlay**: Hide all overlays (boxes + paths)
- **Toggle Heatmap**: Show/hide heatmap canvas
- **VLM Endpoint**: Default RHAIIS route or custom endpoint
- **Custom Models**: Fetch and select available models from endpoint

