"""Scrapy item definitions for horse racing data.

Define here the models for your scraped items.
See documentation in: https://docs.scrapy.org/en/latest/topics/items.html
"""

import scrapy


class RaceEntryItem(scrapy.Item):
    # Race Information
    track = scrapy.Field()
    race_date = scrapy.Field()
    race_number = scrapy.Field()
    race_name = scrapy.Field()
    race_distance = scrapy.Field()
    race_surface = scrapy.Field()
    purse = scrapy.Field()

    # Horse Information
    horse_name = scrapy.Field()
    sire = scrapy.Field()
    age = scrapy.Field()
    sex = scrapy.Field()  # M/F/G from age field like "5G"
    hrn_power_ranking = scrapy.Field()  # The HRN number like "113*"

    # Racing Information
    post_position = scrapy.Field()
    morning_line_odds = scrapy.Field()

    # People
    jockey = scrapy.Field()
    trainer = scrapy.Field()
    owner = scrapy.Field()

    # Additional Fields
    weight = scrapy.Field()
    medication = scrapy.Field()
    equipment = scrapy.Field()
    claim_price = scrapy.Field()

    # Metadata
    entry_url = scrapy.Field()
    scraped_at = scrapy.Field()


class PowerRankingItem(scrapy.Item):
    # Ranking Information
    hrn_ranking = scrapy.Field()
    hrn_power_rating = scrapy.Field()  # The actual power rating number
    horse_name = scrapy.Field()
    horse_url = scrapy.Field()

    # Basic Horse Info
    age = scrapy.Field()
    sex = scrapy.Field()
    color = scrapy.Field()

    # Breeding Information
    sire = scrapy.Field()
    sire_url = scrapy.Field()
    sire_horse_url = scrapy.Field()  # URL to sire's horse profile page
    dam = scrapy.Field()
    dam_url = scrapy.Field()

    # Performance Stats
    starts = scrapy.Field()
    wins = scrapy.Field()
    places = scrapy.Field()
    shows = scrapy.Field()
    earnings = scrapy.Field()

    # Recent Performance
    recent_form = scrapy.Field()  # Last few race results
    last_race_date = scrapy.Field()
    last_race_track = scrapy.Field()
    last_race_result = scrapy.Field()

    # Next Race Information
    next_race_date = scrapy.Field()
    next_race_track = scrapy.Field()

    # Connections
    owner = scrapy.Field()
    trainer = scrapy.Field()
    jockey = scrapy.Field()

    # Metadata
    ranking_date = scrapy.Field()
    scraped_at = scrapy.Field()
    source_url = scrapy.Field()


class SireItem(scrapy.Item):
    # Basic Sire Information
    sire_name = scrapy.Field()
    sire_url = scrapy.Field()

    # Breeding Information
    birth_year = scrapy.Field()
    color = scrapy.Field()
    sire_of_sire = scrapy.Field()  # Grandsire
    dam_of_sire = scrapy.Field()

    # Racing Record
    racing_starts = scrapy.Field()
    racing_wins = scrapy.Field()
    racing_places = scrapy.Field()
    racing_shows = scrapy.Field()
    racing_earnings = scrapy.Field()

    # Stud Information
    stud_fee = scrapy.Field()
    stud_farm = scrapy.Field()
    stud_location = scrapy.Field()
    first_crop_year = scrapy.Field()

    # Progeny Statistics
    progeny_foals = scrapy.Field()
    progeny_starters = scrapy.Field()
    progeny_winners = scrapy.Field()
    progeny_stakes_winners = scrapy.Field()
    progeny_earnings = scrapy.Field()

    # Performance Metrics
    winning_percentage = scrapy.Field()
    earnings_per_starter = scrapy.Field()
    stakes_winners_percentage = scrapy.Field()

    # Metadata
    scraped_at = scrapy.Field()
    source_url = scrapy.Field()


class HorseRacingScraperScrapyItem(scrapy.Item):
    pass
