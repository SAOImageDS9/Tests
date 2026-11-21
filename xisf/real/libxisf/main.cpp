/************************************************************************
 * LibXISF - library to load and save XISF files                        *
 * Copyright (C) 2026 Dušan Poizl                                       *
 *                                                                      *
 * This program is free software: you can redistribute it and/or modify *
 * it under the terms of the GNU General Public License as published by *
 * the Free Software Foundation, either version 3 of the License, or    *
 * (at your option) any later version.                                  *
 *                                                                      *
 * This program is distributed in the hope that it will be useful,      *
 * but WITHOUT ANY WARRANTY; without even the implied warranty of       *
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the        *
 * GNU General Public License for more details.                         *
 *                                                                      *
 * You should have received a copy of the GNU General Public License    *
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.*
 ************************************************************************/

#include <iostream>
#include "libxisf.h"

using namespace LibXISF;

void benchmark();

#define TEST(cond, msg) if(cond){ std::cerr << msg << std::endl; return 1; }
#define TEST_PROP(id_, type_, val_) if(property.id == id_ && (property.value.type() != Variant::Type::type_ || property.value.value<type_>() != val_)){ std::cerr << "Property " id_ " doesn't match" << std::endl; return 1; }
#define TEST_PROPCX(id_, type_, real_, imag_) if(property.id == id_ && (property.value.type() != Variant::Type::type_ || property.value.value<type_>().real != real_ || property.value.value<type_>().imag != imag_)) \
                                                { std::cerr << "Property " id_ " doesn't match" << std::endl; return 1; }
#define TEST_PROPSTR(id_, type_, val_) if(property.id == id_ && (property.value.type() != Variant::Type::type_ || property.value.toString() != Variant(val_).toString())){ std::cerr << "Property " id_ " doesn't match" << std::endl; return 1; }

int main(int argc, char **argv)
{
    try
    {
        if (argc < 2)
        {
            XISFWriter writer;
            Image image(5, 7);
            image.setImageType(Image::Light);
            image.addProperty(Property("PropertyString", "Hello XISF"));
            image.addProperty(Property("PropertyBoolean", (Boolean)true));
            image.addProperty(Property("PropertyInt8", (Int8)(8)));
            image.addProperty(Property("PropertyInt16", (Int16)16));
            image.addProperty(Property("PropertyInt32", 32));
            image.addProperty(Property("PropertyUInt8", (UInt8)8));
            image.addProperty(Property("PropertyUInt16", (UInt16)(16)));
            image.addProperty(Property("PropertyUInt32", (UInt32)32));
            image.addProperty(Property("PropertyFloat32", (Float32) 0.32));
            image.addProperty(Property("PropertyFloat64", (Float64) 0.64));
            image.addProperty(Property("PropertyComplex32", Complex32{3.0, -2.0}));
            image.addProperty(Property("PropertyComplex64", Complex64{-3.0, 2.0}));
            image.addProperty(Property("VectorUInt16", UI16Vector({23, 45, 86})));
            image.addProperty(Property("VectorComplex32", C32Vector({{1, 2}, {3, 4}, {5, 6}})));
            image.addProperty(Property("Vector64", F64Vector({1.0, 2.0, 3.0})));
            image.addProperty(Property("Vector64Empty", F64Vector()));
            UI16Matrix m(2, 3);
            m(0, 0) = 0;
            m(0, 1) = 1;
            m(0, 2) = 2;
            m(1, 0) = 10;
            image.addProperty(Property("UI16Matrix", m));
            uint16_t *imageData = image.imageData<uint16_t>();
            for(uint64_t i = 0; i < image.height() * image.width(); i++)
            {
                imageData[i] = i;
            }
            std::tm tm = {12, 22, 23, 1, 2, 2023 - 1900, 0, 0, 0};
            image.addProperty(Property("TimeObs", tm));
            image.addFITSKeyword({"RA", "226.9751163116387", "Right ascension of the center of the image (deg)"});
            image.addFITSKeyword({"DEC", "62.02302376908295", "Declination of the center of the image (deg)"});
            image.setCompression(DataBlock::Zlib);
            writer.writeImage(image);

            image.setImageType(Image::Flat);
            image.setCompression(DataBlock::LZ4);
            image.setByteshuffling(true);
            writer.writeImage(image);
            ByteArray data;
            std::cout << "Saving image" << std::endl;
            writer.save(data);

            XISFReader reader;
            std::cout << "Loading image" << std::endl;
            reader.open(data);
            const Image &img0 = reader.getImage(0);
            const Image &img1 = reader.getImage(1);

            auto properties = img0.imageProperties();
            TEST(image.imageProperties().size() != img0.imageProperties().size(), "Property count doesn't match");
            TEST(std::memcmp(image.imageData(), img0.imageData(), image.imageDataSize()), "Images doesn't match");
            TEST(std::memcmp(image.imageData(), img1.imageData(), image.imageDataSize()), "Images doesn't match");

            for(auto &property : properties)
            {
                TEST_PROP("PropertyString", String, "Hello XISF");
                TEST_PROP("PropertyBoolean", Boolean, true);
                TEST_PROP("PropertyInt8", Int8, (Int8)8);
                TEST_PROP("PropertyInt16", Int16, (Int16)16);
                TEST_PROP("PropertyInt32", Int32, (Int32)32);
                TEST_PROP("PropertyUInt8", UInt8, (UInt8)8);
                TEST_PROP("PropertyUInt16", UInt16, (UInt16)16);
                TEST_PROP("PropertyUInt32", UInt32, (UInt32)32);
                TEST_PROP("PropertyFloat32", Float32, (Float32) 0.32);
                TEST_PROP("PropertyFloat64", Float64, (Float64) 0.64);
                TEST_PROPCX("PropertyComplex32", Complex32, 3.0, -2.0);
                TEST_PROPCX("PropertyComplex64", Complex64, -3.0, 2.0);
                TEST_PROP("VectorUInt16", UI16Vector, UI16Vector({23, 45, 86}));
                TEST_PROPSTR("VectorComplex32", C32Vector, C32Vector({{1, 2}, {3, 4}, {5, 6}}));
                TEST_PROP("Vector64", F64Vector, F64Vector({1.0, 2.0, 3.0}));
                TEST_PROP("Vector64Empty", F64Vector, F64Vector());
            }

            XISFModify mod;
            mod.open(data);
            mod.addFITSKeyword(0, {"NEWKEY", "1.0", ""});
            mod.updateFITSKeyword(0, {"OBJECT", "M42", ""}, true);

            ByteArray data2;
            mod.save(data2);
            reader.open(data2);
            const Image &imgMod = reader.getImage(0, false);
            auto fitsKeywords = imgMod.fitsKeywords();
            TEST(fitsKeywords.size() != 4, "FITS keyword were not added");
            TEST(fitsKeywords[0].name != "RA", "Incorrect FITS RA keyword");
            TEST(fitsKeywords[1].name != "DEC", "Incorrect FITS DEC keyword");
            TEST(fitsKeywords[2].name != "NEWKEY", "Incorrect FITS NEWKEY keyword");
            TEST(fitsKeywords[3].name != "OBJECT", "Incorrect FITS OBJECT keyword");
        }
        else if(argc == 2 && std::strcmp(argv[1], "bench") == 0)
        {
            benchmark();
        }
        else
        {
            LibXISF::XISFReader reader;
            reader.open(LibXISF::String(argv[1]));
            TEST(reader.imagesCount() < 1, "No image");

            const LibXISF::Image &image = reader.getImage(0);
            if(std::strstr(argv[1], "subblock-lz4hc-sh.xisf"))
            {
                TEST(image.compression() != LibXISF::DataBlock::LZ4HC, "Invalid compression codec");
                TEST(image.width() != 1449, "Invalid width")
                TEST(image.height() != 1449, "Invalid height");
                TEST(image.imageDataSize() != 8398404, "Invalid data size");
            }
            else if(std::strstr(argv[1], "endian.xisf"))
            {
                TEST(reader.imagesCount() != 2, "Image count is not 2");
                const LibXISF::Image &image2 = reader.getImage(1);
                ByteArray data(5 * 7 * 2);
                uint16_t *ptr = reinterpret_cast<uint16_t*>(data.data());
                for(uint64_t i = 0; i < 5 * 7; i++)
                    ptr[i] = i;

                TEST(image.imageDataSize() != 5 * 7 * 2, "Invalid data size");
                TEST(std::memcmp(image.imageData(), data.constData(),  image.imageDataSize()), "Image data doesn't match");
                TEST(std::memcmp(image2.imageData(), data.constData(), image.imageDataSize()), "Image2 data doesn't match");

                auto properties = image.imageProperties();
                TEST(properties.size() != 18, "Property count doesn't match");
                for(auto &property : properties)
                {
                    TEST_PROP("PropertyString", String, "Hello XISF");
                    TEST_PROP("PropertyBoolean", Boolean, true);
                    TEST_PROP("PropertyInt8", Int8, (Int8)8);
                    TEST_PROP("PropertyInt16", Int16, (Int16)16);
                    TEST_PROP("PropertyInt32", Int32, (Int32)32);
                    TEST_PROP("PropertyUInt8", UInt8, (UInt8)8);
                    TEST_PROP("PropertyUInt16", UInt16, (UInt16)16);
                    TEST_PROP("PropertyUInt32", UInt32, (UInt32)32);
                    TEST_PROP("PropertyFloat32", Float32, (Float32) 0.32);
                    TEST_PROP("PropertyFloat64", Float64, (Float64) 0.64);
                    TEST_PROPCX("PropertyComplex32", Complex32, 3.0, -2.0);
                    TEST_PROPCX("PropertyComplex64", Complex64, -3.0, 2.0);
                    TEST_PROP("VectorUInt16", UI16Vector, UI16Vector({23, 45, 86}));
                    TEST_PROPSTR("VectorComplex32", C32Vector, C32Vector({{1, 2}, {3, 4}, {5, 6}}));
                    TEST_PROP("Vector64", F64Vector, F64Vector({1.0, 2.0, 3.0}));
                    TEST_PROP("Vector64Empty", F64Vector, F64Vector());
                }
            }
            else
            {
                TEST(image.width() != 8, "Invalid width")
                TEST(image.height() != 10, "Invalid height");
                TEST(image.imageDataSize() != 80*2, "Invalid data size");
                if(std::strstr(argv[1], "lz4"))
                {
                    TEST(image.compression() != LibXISF::DataBlock::LZ4, "Invalid compression codec");
                }
                else
                {
                    TEST(image.compression() != LibXISF::DataBlock::None, "Invalid compression codec");
                }
            }
            TEST(image.colorSpace() != LibXISF::Image::Gray, "Invalid color space");
            TEST(image.pixelStorage() != LibXISF::Image::Planar, "Invalid pixel storage");
            //TEST(!image.dataBlock.embedded, "Not embedded");
        }
    }
    catch (const LibXISF::Error &e)
    {
        std::cout << e.what() << std::endl;
        return 2;
    }
    return 0;
}
