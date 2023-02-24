#include "config.h"
#include "libavutil/imgutils.h"
#include "libavformat/rtsp.h"
#include "libavcodec/avcodec.h"
#include "libswscale/swscale.h"
#include "libavutil/avstring.h"
#include "libavutil/avassert.h"
#include <stdio.h>
#include <stdbool.h>
#include <time.h>
#if HAVE_UNISTD_H
#include <unistd.h>
#endif
#if HAVE_IO_H
#include <io.h>
#endif
#define SEC_TO_NS(sec) ((sec)*1000000000)

const struct { const char* name; int level; } log_levels[] = {
	{ "quiet"  , AV_LOG_QUIET   },
	{ "panic"  , AV_LOG_PANIC   },
	{ "fatal"  , AV_LOG_FATAL   },
	{ "error"  , AV_LOG_ERROR   },
	{ "warning", AV_LOG_WARNING },
	{ "info"   , AV_LOG_INFO    },
	{ "verbose", AV_LOG_VERBOSE },
	{ "debug"  , AV_LOG_DEBUG   },
	{ "trace"  , AV_LOG_TRACE   },
};

typedef struct context {
	const char* input;
	const char* output;
	int extract_index;
	int loglevel;
	bool tcp;
	bool wait_start_frame;
	bool wait_key_frame;
	const char* error_message;
} AppContext;
void exit_program(int ret)
{
	exit(ret);
}
uint64_t get_timestamp()
{
	/// Convert seconds to nanoseconds
	uint64_t nanoseconds;
	struct timespec ts;
	int return_code = clock_gettime(CLOCK_MONOTONIC_RAW, &ts);
	if (return_code == -1)
	{
		printf("Failed to obtain timestamp. errno = %i: %s\n", errno,
			strerror(errno));
		nanoseconds = UINT64_MAX; // use this to indicate error
	}
	else
	{
		// `ts` now contains your timestamp in seconds and nanoseconds! To 
		// convert the whole struct to nanoseconds, do this:
		nanoseconds = SEC_TO_NS((uint64_t)ts.tv_sec) + (uint64_t)ts.tv_nsec;
	}
}

double ntp_timestamp(AVFormatContext *pFormatCtx, uint32_t *last_rtcp_ts, double *base_time) {
	RTSPState* rtsp_state = (RTSPState*) pFormatCtx->priv_data;
	RTSPStream* rtsp_stream = rtsp_state->rtsp_streams[0];
	RTPDemuxContext* rtp_demux_context = (RTPDemuxContext*) rtsp_stream->transport_priv;

	
	av_log(NULL, AV_LOG_DEBUG,"====================================\n");
	av_log(NULL, AV_LOG_DEBUG,"RTSP timestamps:\n");
	av_log(NULL, AV_LOG_DEBUG,"timestamp:                %u\n", rtp_demux_context->timestamp);
	av_log(NULL, AV_LOG_DEBUG,"base_timestamp:           %u\n", rtp_demux_context->base_timestamp);
	av_log(NULL, AV_LOG_DEBUG,"last_rtcp_ntp_time:       %lu\n", rtp_demux_context->last_rtcp_ntp_time);
	av_log(NULL, AV_LOG_DEBUG,"last_rtcp_reception_time: %lu\n", rtp_demux_context->last_rtcp_reception_time);
	av_log(NULL, AV_LOG_DEBUG,"first_rtcp_ntp_time:      %lu\n", rtp_demux_context->first_rtcp_ntp_time);
	av_log(NULL, AV_LOG_DEBUG,"last_rtcp_timestamp:      %u\n", rtp_demux_context->last_rtcp_timestamp);
	av_log(NULL, AV_LOG_DEBUG,"diff: %d\n",(rtp_demux_context->timestamp-rtp_demux_context->base_timestamp));
	av_log(NULL, AV_LOG_DEBUG,"====================================\n");
	
	uint32_t new_rtcp_ts = rtp_demux_context->last_rtcp_timestamp;
	uint64_t last_ntp_time = 0;
	uint32_t seconds = 0;
	uint32_t fraction = 0;
	double useconds = 0;
	int32_t d_ts = 0;

	if(new_rtcp_ts != *last_rtcp_ts){
		*last_rtcp_ts=new_rtcp_ts;
		last_ntp_time = rtp_demux_context->last_rtcp_ntp_time;
		seconds = ((last_ntp_time >> 32) & 0xffffffff)-2208988800;
		fraction  = (last_ntp_time & 0xffffffff);
		useconds = ((double) fraction / 0xffffffff);
		*base_time = seconds+useconds;
	}

	d_ts = rtp_demux_context->timestamp-*last_rtcp_ts;
	return *base_time+d_ts/90000.0;
}


int decode(int* got_frame, AVFrame* pFrame, AVCodecContext* pCodecCtx, AVPacket* packet) {
	int ret = 0;
	*got_frame = 0;

	ret = avcodec_send_packet(pCodecCtx, packet);

	if (ret < 0)
		return ret == AVERROR_EOF ? 0 : ret;

	ret = avcodec_receive_frame(pCodecCtx, pFrame);

	if (ret < 0 && ret != AVERROR(EAGAIN) && ret != AVERROR_EOF)
		return ret;

	if (ret >= 0)
		*got_frame = 1;

	return 0;
}

int write_jpeg(AVCodecContext *pCodecCtx, AVFrame *pFrame, const char* jpeg_filename)
{
	AVCodecContext         *pOCodecCtx;
	const AVCodec                *pOCodec;
	uint8_t                *Buffer;
	int                     BufSiz;
	enum AVPixelFormat      ImgFmt = AV_PIX_FMT_YUVJ420P;
	FILE                   *jpeg_file;

	BufSiz = av_image_get_buffer_size(ImgFmt, pCodecCtx->width, pCodecCtx->height, 1);
	Buffer = (uint8_t *)malloc ( BufSiz );
	if ( Buffer == NULL )
	{
		av_log(NULL, AV_LOG_ERROR, "malloc for image failed \n");
		free(Buffer);
		return (0);
	}
	memset ( Buffer, 0, BufSiz );

	pOCodecCtx = avcodec_alloc_context3 ( NULL );
	if ( !pOCodecCtx ) 
	{
		av_log(NULL, AV_LOG_ERROR, "no pOCodecCtx\n");
		free ( Buffer );
		return ( 0 );
	}

	av_log(NULL, AV_LOG_TRACE, "Preparing file %s\n", jpeg_filename);
	pOCodecCtx->bit_rate      = pCodecCtx->bit_rate;
	pOCodecCtx->width         = pCodecCtx->width;
	pOCodecCtx->height        = pCodecCtx->height;
	pOCodecCtx->pix_fmt       = ImgFmt;
	pOCodecCtx->codec_id      = AV_CODEC_ID_MJPEG;
	pOCodecCtx->codec_type    = AVMEDIA_TYPE_VIDEO;
//	pOCodecCtx->time_base.num = pCodecCtx->time_base.num;
//	pOCodecCtx->time_base.den = pCodecCtx->time_base.den;
	pOCodecCtx->time_base = pCodecCtx->time_base;
	
	if ((pOCodecCtx->time_base.num == 0) || (pOCodecCtx->time_base.den == 0))
	{
		av_log(NULL, AV_LOG_WARNING, "pOCodecCtx->time_base = 0\n");
		pOCodecCtx->time_base.num = 1;
		pOCodecCtx->time_base.den = 1;
	}
	pOCodec = avcodec_find_encoder ( pOCodecCtx->codec_id );
	if ( !pOCodec ) 
	{
		av_log(NULL, AV_LOG_ERROR, "no pOCodec\n");
		free ( Buffer );
		return ( 0 );
	}

	if ( avcodec_open2 ( pOCodecCtx, pOCodec, NULL ) < 0 )
	{
		av_log(NULL, AV_LOG_ERROR, "avcodec_open2 failed\n");
		free ( Buffer );
		return ( 0 );
	}
	
	pOCodecCtx->mb_lmin = pOCodecCtx->qmin * FF_QP2LAMBDA;
	pOCodecCtx->mb_lmax = pOCodecCtx->qmax * FF_QP2LAMBDA;

	pOCodecCtx->flags = AV_CODEC_FLAG_QSCALE;
	pOCodecCtx->global_quality = pOCodecCtx->qmin * FF_QP2LAMBDA;

	pFrame->pts = 1;
	pFrame->quality = pOCodecCtx->global_quality;

	AVPacket pOutPacket;
	pOutPacket.data = Buffer;
	pOutPacket.size = BufSiz;

	int got_packet_ptr = 0;
	int result = avcodec_send_frame(pOCodecCtx, pFrame);
	if (result == AVERROR_EOF)
	{
		av_log(NULL, AV_LOG_ERROR, "avcodec_send_frame failed: AVERROR_EOF\n");
		free(Buffer);
		return (0);
	}
	else if (result < 0)
	{
		av_log(NULL, AV_LOG_ERROR, "avcodec_send_frame failed\n");
		free(Buffer);
		return (0);
	}
	else {
		av_log(NULL, AV_LOG_TRACE, "Opening file %s\n", jpeg_filename);
		jpeg_file = fopen (jpeg_filename, "wb" );
		if (jpeg_file) {
			AVPacket* pkt = av_packet_alloc();
			if (pkt != NULL) {
				while (avcodec_receive_packet(pOCodecCtx, pkt) == 0) {
					fwrite(pkt->data, 1, pkt->size, jpeg_file);
					av_packet_unref(pkt);
				}
				av_packet_free(&pkt);
				fclose(jpeg_file);
			}
			else {
				av_log(NULL, AV_LOG_ERROR, "av_packet_alloc failed\n");
				free(Buffer);
				return (0);
			}
		}
		else
		{
			av_log(NULL, AV_LOG_ERROR, "Error while opening file %s\n", jpeg_filename);
			free(Buffer);
			return (0);
		}
	}
	avcodec_close ( pOCodecCtx );
	free ( Buffer );
	return ( BufSiz );
}
const char* get_log_level(int level)
{
	int j = 0;
	for (j = 0; j < FF_ARRAY_ELEMS(log_levels); j++) {
		if (log_levels[j].level == level) {
			return log_levels[j].name;
		}
	}
	return log_levels[j].name;
}
int parse_command_line(int argc, char* argv[], AppContext* pContext)
{
	const char* token;
	const char* plevel;
	bool level_found = false;
	int  i = 1;
	int j = 0;


	if (pContext) {
		while ((i < argc) && (argv[i])) {			
			token = argv[i++];
			

			if (*token == '-' ) {
				switch (*(++token))
				{
				case 'i':
					if (i < argc) {
						pContext->input = av_strdup(argv[i++]);
					}
					break;
				case 'o':
					if (i < argc) {;
						pContext->output = av_strdup(argv[i++]);
					}
					break;
				case 'e':
					if (i < argc) {
						pContext->extract_index = atoi(argv[i++]);
					}
					break;
				case 's':
					pContext->wait_start_frame = true;
					break;					
				case 'k':
					pContext->wait_key_frame = true;
					break;					
				case 'v':
					if (i < argc) {
						plevel = argv[i++];
						for (j = 0; j < FF_ARRAY_ELEMS(log_levels); j++) {
							if (!strcmp(log_levels[j].name, plevel)) {
								pContext->loglevel = log_levels[j].level;
								av_log_set_level(pContext->loglevel);
								level_found = true;
							}
						}
						if (level_found == false) {
							pContext->error_message = av_strdup("log level incorrect");
							return (0);
						}
					}
					break;
				default:
					pContext->error_message = av_strdup("Option not valid");
					return (0);
					break;

				};
			}
			else {
				pContext->error_message = av_strdup("Option expected: -");
				return (0);
			}
		}
		if((pContext->input)&&
			(pContext->output))
			return ( 1 );
		else
		{
			pContext->error_message = av_strdup("input or output parameter no set");
			return (0);
		}
	}
	return ( 0 );
}
int show_command_line(AppContext* pContext, const char* pVersion)
{
	if (pContext) {
		if (pContext->error_message) {
			printf("Extractframe error: %s\n", pContext->error_message);
		}
	}
	printf("Extractframe version: %s\nSyntax: \n   extractframe -i input -e rate -o output -v [quiet|panic|fatal|error|warning|info|verbose|debug|trace]\n", pVersion);
	
	return( 0 );
}
AppContext* av_context_alloc(void)
{
	AppContext* pctx = av_mallocz(sizeof(AppContext));
	if (!pctx)
		 return pctx;
	pctx->input = NULL;
	pctx->output = NULL;
	pctx->tcp = true;
	pctx->wait_start_frame = false;
	pctx->wait_key_frame = false;
	pctx->extract_index = 30;
	pctx->loglevel = AV_LOG_INFO;
	pctx->error_message = NULL;
	return pctx;
}
int get_time_string(double ts, char* pbuf, int lbuf)
{
	struct timeval tv;
	struct tm *tm;
	uint32_t sec = 0;
	uint32_t usec = 0;
	double diff = 0;
	sec = (uint32_t) ts;
	diff = ts-sec;
	usec = diff*1000000;
	tv.tv_sec = sec;
	tv.tv_usec = usec;
	tm=localtime(&tv.tv_sec);
	snprintf(pbuf, lbuf,"%04d/%02d/%02d-%02d:%02d:%02d-%06ld", tm->tm_year+1900, tm->tm_mon+1, tm->tm_mday, tm->tm_hour, tm->tm_min,
		tm->tm_sec, tv.tv_usec);
	return 1;
}
int isStartFrame(uint8_t *data[4])
{

	int start_frame = 1;
	for (int i = 0; i < 4; i++)
	{
		av_log(NULL, AV_LOG_DEBUG, "Index: %d - pointeur:         %p\n",i,data[i]);
		if(data[i])
		{
			for (int j = 0; j < 16; j++)
			{
				av_log(NULL, AV_LOG_DEBUG, "  Index: %d - value:            %02X\n",i,data[i][j]);
				if(data[i][j] != 0)
					return 0;					
			}
		}
		/*
		if( (*(data[0]+i)!=0) ||
			(*(data[0]+i)!=0) ||
			(*(data[2]+i)!=0)  ||
			(*(data[3]+i)!=0))
			return 0;
		*/
	}
	return 1;
}
int is_rtsp_source(const char* source)
{
	if((source[0] == 'r')&&
	(source[1] == 't')&&
	(source[2] == 's')&&
	(source[3] == 'p')&&
	(source[4] == ':'))
		return 1;
	return 0;
}
double get_frame_rate(AVFormatContext   *pFormatCtx){
	int VideoStreamIndx = -1;
	/* find first stream */
	for(int i=0; i<pFormatCtx->nb_streams ;i++ )
	{
		if( pFormatCtx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO ) 
		/* if video stream found then get the index */
		{
		VideoStreamIndx = i;
		break;
		}
	}
	if(VideoStreamIndx == -1)
		return -1;
	return av_q2d(pFormatCtx->streams[VideoStreamIndx]->r_frame_rate);
}
int main(int argc, char *argv[]) {
	AppContext        *papp_context = NULL;
	const char* pVersion = "1.0.0.1";
	AVCodecParameters *origin_par = NULL;
	const AVCodec     *pCodec = NULL;
	AVFormatContext   *pFormatCtx = NULL;
	AVCodecContext    *pCodecCtx = NULL;
	AVFrame           *pFrame = NULL;
	AVPacket          *pPacket;
	int               videoStream = -1;
	//uint32_t		  frame_size = 1920*1080*4;
	uint8_t			  network_mode = 1;
	char              time_buffer[256];
	int result;

	papp_context = av_context_alloc();
	if (parse_command_line(argc, argv, papp_context) <= 0) {
		show_command_line(papp_context, pVersion);
		exit_program(1);
	}
	av_log(NULL, AV_LOG_INFO, "Launching application with: \n  Input: %s \n rtsp source: %s\n  Output: %s \n  Rate: %d \n  wait for key frame: %s \n  wait for start frame: %s \n  Protocol: %s\n  Loglevel: %s\n",
		papp_context->input,
		is_rtsp_source(papp_context->input)?"true":"false",
		papp_context->output,
		papp_context->extract_index,
		papp_context->wait_key_frame?"true":"false",
		papp_context->wait_start_frame?"true":"false",
		papp_context->tcp == true ? "tcp":"udp",
		get_log_level(papp_context->loglevel));
	const char* rtsp_source = papp_context->input;
	avformat_network_init();
	pPacket = av_packet_alloc();
	AVDictionary* opts = NULL;
	av_dict_set(&opts, "stimeout", "5000000", 0);

	if (network_mode == 0) {
		av_log(NULL, AV_LOG_INFO, "Opening UDP stream\n");
		result = avformat_open_input(&pFormatCtx, rtsp_source, NULL, &opts);
	} else {
		av_dict_set(&opts, "rtsp_transport", "tcp", 0);
		av_log(NULL, AV_LOG_INFO, "Opening TCP stream\n");
		result = avformat_open_input(&pFormatCtx, rtsp_source, NULL, &opts);
	}

	if (result < 0) {
		av_log(NULL, AV_LOG_ERROR, "Couldn't open stream\n");
		return 0;
	}

	result = avformat_find_stream_info(pFormatCtx, NULL);
	if (result < 0) {
		av_log(NULL, AV_LOG_ERROR, "Couldn't find stream information\n");
		return 0;
	}

	videoStream = av_find_best_stream(pFormatCtx, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
	if (videoStream == -1) {
		av_log(NULL, AV_LOG_ERROR, "Couldn't find video stream\n");
		return 0;
	}

	origin_par = pFormatCtx->streams[videoStream]->codecpar;
	pCodec = avcodec_find_decoder(origin_par->codec_id);	

	if (pCodec == NULL) {
		av_log(NULL, AV_LOG_ERROR,"Unsupported codec\n");
		return 0;
	}

	pCodecCtx = avcodec_alloc_context3(pCodec);

	if (pCodecCtx == NULL) {
		av_log(NULL, AV_LOG_ERROR, "Couldn't allocate codec context\n");
		return 0;
	}

	result = avcodec_parameters_to_context(pCodecCtx, origin_par);
	if (result) {
		av_log(NULL, AV_LOG_ERROR, "Couldn't copy decoder context\n");
		return 0;
	}

	result = avcodec_open2(pCodecCtx, pCodec, NULL);
	if (result < 0) {
		av_log(NULL, AV_LOG_ERROR, "Couldn't open decoder\n");
		return 0;
	}

	pFrame = av_frame_alloc();
	if (pFrame == NULL) {
		av_log(NULL, AV_LOG_ERROR, "Couldn't allocate frame\n");
		return 0;
	}

	int byte_buffer_size = av_image_get_buffer_size(pCodecCtx->pix_fmt, pCodecCtx->width, pCodecCtx->height, 16);
	//byte_buffer_size = byte_buffer_size < frame_size ? byte_buffer_size : frame_size;

	int number_of_written_bytes;
	int got_frame;
	uint32_t last_rtcp_ts = 0;
	double base_time = 0;

	uint8_t* frame_data = NULL;

	FILE *output_file = NULL;
	AVFrame           *pFrameRGB = NULL;
	int               numBytes;
	uint8_t           *buffer = NULL;
	struct SwsContext *sws_ctx = NULL;
	int i = 0;
	bool start_frame_detected = false;
	double start_frame_ts = 0;
	// if wait_key_frame or wait_start_frame are true the capture will not start immmediatly
	if((papp_context->wait_key_frame == true)||(papp_context->wait_start_frame == true))
		i = -1;

	// Allocate an AVFrame structure
	pFrameRGB=av_frame_alloc();
	if(pFrameRGB==NULL)
	{
		av_log(NULL, AV_LOG_ERROR, "Couldn't allocate RGB frame\n");
		return -1;
	}

	// Determine required buffer size and allocate buffer
	numBytes=av_image_get_buffer_size(AV_PIX_FMT_RGB24, pCodecCtx->width, pCodecCtx->height, 1);
	buffer=(uint8_t *)av_malloc(numBytes*sizeof(uint8_t));

	// Assign appropriate parts of buffer to image planes in pFrameRGB
	// Note that pFrameRGB is an AVFrame, but AVFrame is a superset
	// of AVPicture
	av_image_fill_arrays(pFrameRGB->data, pFrameRGB->linesize, buffer, 
		AV_PIX_FMT_RGB24, pCodecCtx->width, pCodecCtx->height, 1);

	// initialize SWS context for software scaling
	sws_ctx = sws_getContext(pCodecCtx->width,
		pCodecCtx->height,
		pCodecCtx->pix_fmt,
		pCodecCtx->width,
		pCodecCtx->height,
		AV_PIX_FMT_RGB24,
		SWS_BILINEAR,
		NULL,
		NULL,
		NULL);
	
	bool rtsp = false;

	if(is_rtsp_source(rtsp_source)){			
		rtsp = true;
		av_log(NULL, AV_LOG_INFO, "RTSP source\n");
	}
	else{
		av_log(NULL, AV_LOG_INFO, "Not RTSP source\n");
	}
	double fps = get_frame_rate(pFormatCtx);
	
	start_frame_detected = false;

	while (av_read_frame(pFormatCtx, pPacket) >= 0) {
		if (decode(&got_frame, pFrame, pCodecCtx, pPacket) < 0) {
			av_log(NULL, AV_LOG_ERROR, "Decoding error\n");
			break;
		}

		if (got_frame) {
			
			av_log(NULL, AV_LOG_DEBUG,"====================================\n");
			av_log(NULL, AV_LOG_DEBUG,"Packet:\n");
			av_log(NULL, AV_LOG_DEBUG,"size:               %u\n", pPacket->size);
			av_log(NULL, AV_LOG_DEBUG,"dts:                %lu\n", pPacket->dts);
			av_log(NULL, AV_LOG_DEBUG,"pts:                %lu\n", pPacket->pts);
			av_log(NULL, AV_LOG_DEBUG,"stream_index:       %u\n", pPacket->stream_index);
			av_log(NULL, AV_LOG_DEBUG,"duration:           %lu\n", pPacket->duration);
			av_log(NULL, AV_LOG_DEBUG,"pos:                %lu\n", pPacket->pos);
			av_log(NULL, AV_LOG_DEBUG,"====================================\n");
			
			double ts = 0;
			if(rtsp == true)
				ts = ntp_timestamp(pFormatCtx, &last_rtcp_ts, &base_time);
			else{
				//av_log(NULL, AV_LOG_INFO, "DTS: %lu %lu %lu Duration: %lu FPS %lu/%lu fps: %f \n",pPacket->dts,pFrame->pts,pFrame->pkt_dts,pPacket->duration,pFrame->time_base.num,pFrame->time_base.den,fps);
				//ts = pPacket->dts/12800.0;
				if((pPacket->duration>0)&&(pPacket->dts>0)&&(fps>0))
					ts = pPacket->dts/(pPacket->duration*fps);
				else
					ts = pPacket->dts;
				//av_log(NULL, AV_LOG_INFO, "DTS: %lu\n",pPacket->dts);
			}
			//av_log(NULL, AV_LOG_INFO, "Timestamp: %f %d %d\n",ts,pFrame->key_frame,i);
			av_log(NULL, AV_LOG_DEBUG, "Timestamp: %018.6f\n",ts);
			if(get_time_string(ts,time_buffer, sizeof(time_buffer)))
			{
				av_log(NULL, AV_LOG_DEBUG, "Time:      %s\n",time_buffer);
			}
			// if wait_key_frame and key_frame detected capture can start
			if(pFrame->key_frame && (papp_context->wait_key_frame == true) && (ts>0))
				i = 0;
			

			// if wait_start_frame and key_frame detected and ts valid, capture can start if start frame detected
			if(pFrame->key_frame && (papp_context->wait_start_frame == true) && (((rtsp == true) && (ts>1667466981))||((rtsp == false) && (ts>=0)) ))
			{
				// Convert the image from its native format to RGB
				sws_scale(sws_ctx, (uint8_t const* const*)pFrame->data,
					pFrame->linesize, 0, pCodecCtx->height,
					pFrameRGB->data, pFrameRGB->linesize);

				if(isStartFrame(pFrameRGB->data)){
					av_log(NULL, AV_LOG_INFO, "Timestamp: %018.6f - Start Frame detected\n",ts);
					start_frame_detected = true;
				}
				else
				{
					// is first video frame detected after start frame 
					if(start_frame_detected == true){
						start_frame_detected = false;
						start_frame_ts = ts;
						i = 0;
					}
					av_log(NULL, AV_LOG_DEBUG, "Timestamp: %018.6f - Start Frame detected\n",ts);
				}

			}
			if(i>=papp_context->extract_index){
				i=0;
			}
			// Save the frame to disk
			if((i==0)&&(start_frame_detected == false))
			{
				char ts_string[256];
				char jpeg_filename[256];
				double relative_ts = ts-start_frame_ts;
				uint64_t last_time = 0;
				uint64_t new_time = 0;
				uint64_t diff_time = 0;
				last_time = get_timestamp();

				if(papp_context->wait_start_frame == true)
					snprintf(ts_string, sizeof(ts_string), "%018.6f-%018.6f", ts, relative_ts);
				else
					snprintf(ts_string, sizeof(ts_string), "%018.6f", ts);
				snprintf(jpeg_filename, sizeof(jpeg_filename), papp_context->output, ts_string);


				av_log(NULL, AV_LOG_INFO, "Timestamp: %018.6f - Creating file: %s\n", ts, jpeg_filename);

				// Convert the image from its native format to RGB
				sws_scale(sws_ctx, (uint8_t const* const*)pFrame->data,
					pFrame->linesize, 0, pCodecCtx->height,
					pFrameRGB->data, pFrameRGB->linesize);
				if (write_jpeg(pCodecCtx, pFrame, jpeg_filename) <= 0) {
					av_log(NULL, AV_LOG_ERROR, "Error while storing the frame\n");
					break;
				}
				new_time = get_timestamp();
				diff_time = new_time - last_time;
				av_log(NULL, AV_LOG_DEBUG, "Time: %"PRIu64"  File %s created in %"PRIu64" ns \n", get_timestamp(), jpeg_filename, diff_time);
			}
			if(i>=0){
				i++;
			}
			av_packet_unref(pPacket);
		}
	}
	return 0;
}

