import speech_recognition as sr
from pydub import AudioSegment
from pydub.silence import split_on_silence
import os
import glob
import json


def load_config(file_path):
    with open(file_path, 'r') as f:
        _config = json.load(f)
    return _config


def load_audio_file(file_path):
    audio = AudioSegment.from_file(file_path)
    return audio


def split_audio_on_silence(audio, min_silence_len=250, silence_thresh=-32):
    audio_chunks = split_on_silence(
        audio,
        min_silence_len=min_silence_len,
        silence_thresh=silence_thresh
    )
    return audio_chunks


def transcribe_audio_chunks(audio_chunks, language='en-US', min_silence_len=500):
    recognizer = sr.Recognizer()
    transcript = ""

    current_time = 0

    for i, chunk in enumerate(audio_chunks):
        chunk_length = len(chunk)  # length in milliseconds
        start_time = current_time
        end_time = current_time + chunk_length

        with chunk.export(format="wav") as chunk_file:
            with sr.AudioFile(chunk_file) as audio_file:
                try:
                    audio_data = recognizer.record(audio_file)
                    text = recognizer.recognize_google(audio_data, language=language)
                    transcript += f"{start_time} - {end_time}: {text}\n"
                except sr.UnknownValueError:
                    pass  # skip if speech is not recognized

        current_time += chunk_length + min_silence_len  # update the current time

    return transcript


def process_audio_file(file_path, language, min_silence_len, silence_thresh):
    audio = load_audio_file(file_path)
    audio_chunks = split_audio_on_silence(audio, min_silence_len, silence_thresh)
    transcript = transcribe_audio_chunks(audio_chunks, language, min_silence_len)
    return transcript


def process_directory(input_directory, language, min_silence_len, silence_thresh):
    wav_files = glob.glob(os.path.join(input_directory, "*.wav"))

    for wav_file in wav_files:
        print(f"Processing {wav_file}")
        transcript = process_audio_file(wav_file, language, min_silence_len, silence_thresh)
        output_file = os.path.splitext(wav_file)[0] + ".txt"

        with open(output_file, "w") as f:
            f.write(transcript)
        print(f"Transcript saved to {output_file}\n")


if __name__ == "__main__":
    config = load_config('config.json')
    process_directory(
        config["input_dir"],
        config["language"],
        config["min_silence_len"],
        config["silence_thresh"]
    )
